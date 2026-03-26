import Foundation

struct ScheduleClient {

  static func fetchNHL(teamID: String) async throws -> [HomeTeamGame] {
    try await fetch(sport: "hockey", league: "nhl", teamID: teamID, sport: .nhl)
  }
  static func fetchMLB(teamID: String) async throws -> [HomeTeamGame] {
    try await fetch(sport: "baseball", league: "mlb", teamID: teamID, sport: .mlb)
  }
  static func fetchNFL(teamID: String) async throws -> [HomeTeamGame] {
    try await fetch(sport: "football", league: "nfl", teamID: teamID, sport: .nfl)
  }
  static func fetchNBA(teamID: String) async throws -> [HomeTeamGame] {
    try await fetch(sport: "basketball", league: "nba", teamID: teamID, sport: .nba)
  }
  static func fetchMLS(teamID: String) async throws -> [HomeTeamGame] {
    try await fetch(sport: "soccer", league: "usa.1", teamID: teamID, sport: .mls)
  }
  static func fetchPL(teamID: String) async throws -> [HomeTeamGame] {
    try await fetch(sport: "soccer", league: "eng.1", teamID: teamID, sport: .premierLeague)
  }

  static func fetchF1() async throws -> [HomeTeamGame] {
    let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/racing/f1/scoreboard")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try ESPNRacingParser.parse(data, sport: .f1)
  }

  static func fetchMotoGP() async throws -> [HomeTeamGame] {
    let seasonsURL = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/seasons")!
    var request = URLRequest(url: seasonsURL)
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    let (seasonsData, _) = try await URLSession.shared.data(for: request)
    let seasons = try JSONDecoder().decode([MotoGPSeason].self, from: seasonsData)
    guard let current = seasons.first(where: { $0.current }) ?? seasons.last else { return [] }

    async let upcomingGames: [HomeTeamGame] = {
      let url = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/events?seasonUuid=\(current.id)&isFinished=false")!
      var req = URLRequest(url: url); req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
      let (data, _) = try await URLSession.shared.data(for: req)
      return try MotoGPCalendarParser.parse(data)
    }()
    async let finishedGames: [HomeTeamGame] = {
      let url = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/events?seasonUuid=\(current.id)&isFinished=true")!
      var req = URLRequest(url: url); req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
      let (data, _) = try await URLSession.shared.data(for: req)
      return try MotoGPCalendarParser.parse(data)
    }()
    return try await upcomingGames + finishedGames
  }

  /// Fetch standings summary for a single team. Returns nil on any failure (non-fatal).
  static func fetchStandings(for team: TeamDefinition) async -> HomeTeamTeamSummary? {
    if team.sport.isRacing {
      return try? await StandingsClient.fetchRacing(for: team)
    } else {
      return try? await StandingsClient.fetchTeamSport(for: team)
    }
  }

  // MARK: - Private

  private static func fetch(sport: String, league: String, teamID: String, sport sportEnum: SupportedSport) async throws -> [HomeTeamGame] {
    let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(sport)/\(league)/teams/\(teamID)/schedule")!
    let (data, _) = try await URLSession.shared.data(from: url)
    return try ESPNScheduleParser.parse(data, sport: sportEnum, teamID: teamID)
  }
}

private struct MotoGPSeason: Decodable {
  let id: String
  let current: Bool
}

// MARK: - Standings client

private enum StandingsClient {

  // MARK: Team sports — ESPN standings API

  static func fetchTeamSport(for team: TeamDefinition) async throws -> HomeTeamTeamSummary? {
    let year = Calendar.current.component(.year, from: Date())
    for season in [year, year - 1] {
      if let summary = try await fetchESPN(for: team, season: season, seasonType: 2) { return summary }
      // Some sports/off-season periods return data without seasontype filter
      if let summary = try await fetchESPN(for: team, season: season, seasonType: nil) { return summary }
    }
    return nil
  }

  private static func fetchESPN(for team: TeamDefinition, season: Int, seasonType: Int?) async throws -> HomeTeamTeamSummary? {
    guard var components = URLComponents(string: "https://site.api.espn.com/apis/v2/sports/\(team.sport.sportPath)/\(team.sport.leaguePath)/standings") else { return nil }
    var queryItems = [URLQueryItem(name: "season", value: "\(season)")]
    if let st = seasonType { queryItems.append(URLQueryItem(name: "seasontype", value: "\(st)")) }
    components.queryItems = queryItems
    guard let url = components.url else { return nil }
    let (data, response) = try await URLSession.shared.data(from: url)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return nil }
    let json = try JSONSerialization.jsonObject(with: data)
    guard let summary = findEntry(in: json, espnTeamID: team.espnTeamID, context: []) else { return nil }
    return HomeTeamTeamSummary(compositeID: team.compositeID, record: summary.record, place: summary.place,
                               last10: summary.last10, streak: summary.streak, style: .standard)
  }

  // Recursively walk ESPN standings JSON to find the entry matching espnTeamID
  private static func findEntry(in node: Any, espnTeamID: String, context: [String]) -> RawSummary? {
    if let dict = node as? [String: Any] {
      var ctx = context
      if let name = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
        ctx.append(name)
      }
      if let entries = dict["entries"] as? [[String: Any]] {
        for entry in entries {
          guard let teamDict = entry["team"] as? [String: Any],
                let id = teamDict["id"] as? String, id == espnTeamID else { continue }
          return rawSummary(from: entry, context: ctx)
        }
      }
      for key in ["standings", "children"] {
        if let child = dict[key] {
          if let found = findEntry(in: child, espnTeamID: espnTeamID, context: ctx) { return found }
        }
      }
    } else if let array = node as? [Any] {
      for item in array {
        if let found = findEntry(in: item, espnTeamID: espnTeamID, context: context) { return found }
      }
    }
    return nil
  }

  private struct RawSummary {
    let record: String; let place: String; let last10: String; let streak: String
  }

  private static func rawSummary(from entry: [String: Any], context: [String]) -> RawSummary {
    let statsArray = (entry["stats"] as? [[String: Any]]) ?? []
    var s: [String: String] = [:]
    for stat in statsArray {
      guard let name = stat["name"] as? String,
            let value = stat["displayValue"] as? String,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
      s[name.lowercased()] = value
    }
    // Prefer composed record (wins-losses-ties) to avoid ESPN "overall" string which includes points
    let record = composedRecord(s["wins"], s["losses"], s["otlosses"] ?? s["ties"]) ?? s["record"] ?? s["overall"] ?? "-"
    let rawRank = s["rank"] ?? s["playoffseed"] ?? s["position"]
    let genericNames: Set<String> = ["overall", "standings", "league", "season", "regular season", "nhl", "nfl", "nba", "mlb", "mls"]
    let groupName = context.last(where: { !genericNames.contains($0.lowercased()) }) ?? context.last ?? "Standings"
    let place: String
    if let r = rawRank, let rank = Int(r) { place = "\(ordinal(rank)) in \(groupName)" }
    else { place = rawRank ?? groupName }
    let rawL10 = s["lastten"] ?? s["last10"] ?? s["l10"] ?? s["last 10"] ??
      s.first(where: { $0.key.contains("10") || ($0.key.contains("last") && $0.key.contains("en")) })?.value
    // Strip any ESPN suffix after the W-L record (e.g. "4-4-2, 0 PTS" → "4-4-2")
    let last10 = rawL10.map { String($0.split(separator: ",").first ?? Substring($0)).trimmingCharacters(in: .whitespaces) } ?? "-"
    let streak = s["streak"] ?? "-"
    return RawSummary(record: record, place: place, last10: last10, streak: streak)
  }

  private static func composedRecord(_ wins: String?, _ losses: String?, _ ties: String?) -> String? {
    guard let w = wins, let l = losses else { return nil }
    if let t = ties, t != "0" { return "\(w)-\(l)-\(t)" }
    return "\(w)-\(l)"
  }

  private static func ordinal(_ n: Int) -> String {
    let t = n % 100
    if t == 11 || t == 12 || t == 13 { return "\(n)th" }
    switch n % 10 {
    case 1: return "\(n)st"; case 2: return "\(n)nd"; case 3: return "\(n)rd"
    default: return "\(n)th"
    }
  }

  // MARK: Racing — ESPN racing standings

  static func fetchRacing(for team: TeamDefinition) async throws -> HomeTeamTeamSummary? {
    guard let url = URL(string: "https://site.api.espn.com/apis/v2/sports/racing/\(team.sport.leaguePath)/standings") else { return nil }
    let (data, response) = try await URLSession.shared.data(from: url)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return nil }
    let payload = try JSONDecoder().decode(RacingStandingsPayload.self, from: data)

    for child in payload.children where child.name.lowercased().contains("driver") || child.name.lowercased().contains("rider") {
      for entry in child.standings.entries {
        guard matchesDriver(entry: entry, team: team) else { continue }
        var stats: [String: String] = [:]
        for stat in entry.stats {
          let key = stat.name.lowercased()
          if let v = stat.displayValue?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
            stats[key] = v
          }
        }
        let points = stats["championshippts"] ?? stats["points"] ?? "-"
        let place  = stats["rank"] ?? stats["position"] ?? "-"
        let wins   = stats["wins"] ?? "0"
        let podiums = stats["podiums"] ?? "0"
        return HomeTeamTeamSummary(compositeID: team.compositeID, record: points, place: place,
                                   last10: wins, streak: podiums, style: .racingDriver)
      }
    }
    return nil
  }

  private static func matchesDriver(entry: RacingStandingEntry, team: TeamDefinition) -> Bool {
    // Try ID match first
    if let id = entry.athlete?.id, id == team.espnTeamID { return true }
    // Name match against driverNames
    let candidates = [entry.athlete?.displayName, entry.athlete?.shortName].compactMap { $0 }
    return team.driverNames.contains { driver in
      candidates.contains { candidate in
        candidate.lowercased().contains(driver.lowercased()) || driver.lowercased().contains(candidate.lowercased())
      }
    }
  }
}

// MARK: - Racing standings Decodable models

private struct RacingStandingsPayload: Decodable {
  let children: [RacingStandingsChild]
}
private struct RacingStandingsChild: Decodable {
  let name: String
  let standings: RacingStandingsEntries
}
private struct RacingStandingsEntries: Decodable {
  let entries: [RacingStandingEntry]
}
private struct RacingStandingEntry: Decodable {
  let athlete: RacingAthlete?
  let stats: [RacingStandingStat]
}
private struct RacingAthlete: Decodable {
  let id: String?
  let displayName: String?
  let shortName: String?
}
private struct RacingStandingStat: Decodable {
  let name: String
  let displayValue: String?
}
