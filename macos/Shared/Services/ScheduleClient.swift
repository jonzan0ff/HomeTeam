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
    let year = Calendar.current.component(.year, from: Date())
    // Use full-year date range so all races appear, not just the current scoreboard window.
    // Fetch current year and next year to capture season transitions.
    var games: [HomeTeamGame] = []
    for y in [year, year + 1] {
      let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/racing/f1/scoreboard?dates=\(y)0101-\(y)1231&limit=100")!
      if let (data, _) = try? await URLSession.shared.data(from: url) {
        games += (try? ESPNRacingParser.parse(data, sport: .f1)) ?? []
      }
    }
    // Deduplicate by event ID in case a race straddles the year boundary
    return Array(Dictionary(grouping: games, by: \.id).compactMap(\.value.first))
  }

  // MotoGP class UUID (legacy_id == 3) — consistent across seasons
  private static let motoGPClassUUID = "e8c110ad-64aa-4e8e-8a86-f2f152f6a942"

  static func fetchMotoGP() async throws -> [HomeTeamGame] {
    let seasonsURL = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/seasons")!
    var request = URLRequest(url: seasonsURL)
    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    let (seasonsData, _) = try await URLSession.shared.data(for: request)
    let seasons = try JSONDecoder().decode([MotoGPSeason].self, from: seasonsData)
    guard let current = seasons.first(where: { $0.current }) ?? seasons.last else { return [] }

    // Fetch all events in one call — isFinished=false misses CURRENT (in-weekend) events,
    // and isFinished=true misses them too. Single all-events call gets everything.
    let allEventsURL = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/events?seasonUuid=\(current.id)")!
    var allEventsReq = URLRequest(url: allEventsURL)
    allEventsReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    let (allEventsData, _) = try await URLSession.shared.data(for: allEventsReq)
    var allGames = try MotoGPCalendarParser.parse(allEventsData)
    let circuitTimezones = MotoGPCalendarParser.circuitTimezones(from: allEventsData)

    // Check for live MotoGP race via live timing endpoint (event status stays "CURRENT" during races)
    let liveTiming = await fetchMotoGPLiveTiming()

    // Patch live event: override status to .live and apply live positions
    if let liveEventShortName = liveTiming?.eventShortName {
      allGames = allGames.map { game in
        guard game.status != .final,
              MotoGPCalendarParser.shortName(from: game.id, in: allEventsData) == liveEventShortName
        else { return game }
        return HomeTeamGame(
          id: game.id, sport: game.sport,
          homeTeamID: game.homeTeamID, awayTeamID: game.awayTeamID,
          homeTeamName: game.homeTeamName, awayTeamName: game.awayTeamName,
          homeTeamAbbrev: game.homeTeamAbbrev, awayTeamAbbrev: game.awayTeamAbbrev,
          homeScore: game.homeScore, awayScore: game.awayScore,
          homeRecord: game.homeRecord, awayRecord: game.awayRecord,
          scheduledAt: game.scheduledAt, status: .live,
          statusDetail: liveTiming?.statusDetail,
          venueName: game.venueName,
          broadcastNetworks: game.broadcastNetworks,
          isPlayoff: game.isPlayoff, seriesInfo: game.seriesInfo,
          racingResults: liveTiming?.results
        )
      }
    }

    // Fetch race results/grid/timestamps concurrently:
    //  - finished → RAC classification (final results)
    //  - scheduled → starting grid + exact RAC timestamp
    //  - live games already patched above from live timing
    let finished = allGames.filter { $0.status == .final }
    let scheduled = allGames.filter { $0.status == .scheduled }
    var resultsByID: [String: [RacingResultLine]] = [:]
    var raceDateByID: [String: Date] = [:]
    await withTaskGroup(of: (String, [RacingResultLine], Date?).self) { group in
      for game in finished {
        group.addTask { (game.id, await fetchMotoGPRaceResults(eventID: game.id), nil) }
      }
      for game in scheduled {
        let tz = circuitTimezones[game.id]
        group.addTask {
          async let date = fetchMotoGPRaceDate(eventID: game.id, circuitTimezone: tz)
          async let qual = fetchMotoGPQualifyingResults(eventID: game.id)
          return (game.id, await qual, await date)
        }
      }
      for await (id, results, date) in group {
        if !results.isEmpty { resultsByID[id] = results }
        if let date { raceDateByID[id] = date }
      }
    }
    allGames = allGames.map { game in
      guard game.status != .live else { return game }  // already patched
      var g = game
      if let results = resultsByID[game.id] { g = g.patchingRacingResults(results) }
      if let date = raceDateByID[game.id] { g = g.patchingScheduledAt(date) }
      return g
    }
    return allGames
  }

  /// Live timing result from the Pulselive gateway.
  private struct MotoGPLiveTimingResult {
    let eventShortName: String
    let statusDetail: String
    let results: [RacingResultLine]
  }

  /// Fetches live MotoGP race positions from the timing gateway.
  /// Returns nil if no MotoGP race is currently in progress.
  private static func fetchMotoGPLiveTiming() async -> MotoGPLiveTimingResult? {
    guard let url = URL(string: "https://api.pulselive.motogp.com/motogp/v1/timing-gateway/livetiming-lite") else { return nil }
    var req = URLRequest(url: url)
    req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    guard let (data, _) = try? await URLSession.shared.data(for: req),
          let payload = try? JSONDecoder().decode(MotoGPLiveTimingPayload.self, from: data) else { return nil }

    // Only handle MotoGP race sessions
    guard payload.head.category == "MotoGP",
          payload.head.sessionShortname == "RAC" else { return nil }

    let eventShortName = payload.head.eventShortname
    let remaining = payload.head.remaining ?? ""
    let numLaps = payload.head.numLaps ?? 0
    let currentLap = numLaps - (Int(remaining) ?? 0)
    let statusDetail = "Lap \(currentLap)/\(numLaps)"

    let lines = payload.rider.values
      .sorted { ($0.pos ?? 999) < ($1.pos ?? 999) }
      .compactMap { r -> RacingResultLine? in
        // Surname is ALL CAPS from the API — title-case it (handles "DI GIANNANTONIO" → "Di Giannantonio")
        let surname = r.riderSurname?.lowercased().split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        let name = [r.riderName, surname].compactMap { $0 }.joined(separator: " ")
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let pos = r.pos ?? 0
        return RacingResultLine(
          position: pos,
          driverName: name,
          teamName: nil,
          timeOrGap: nil,
          espnTeamID: TeamCatalog.racingTeamID(forDriverName: name, sport: .motoGP)
        )
      }
    guard !lines.isEmpty else { return nil }
    return MotoGPLiveTimingResult(eventShortName: eventShortName, statusDetail: statusDetail, results: lines)
  }

  /// Fetches the RAC session classification for a finished MotoGP event.
  /// Returns all classified finishers so the widget can find any favorite driver.
  private static func fetchMotoGPRaceResults(eventID: String) async -> [RacingResultLine] {
    // Step 1: find the RAC session UUID
    guard let sessURL = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/sessions?eventUuid=\(eventID)&categoryUuid=\(motoGPClassUUID)") else { return [] }
    var sessReq = URLRequest(url: sessURL)
    sessReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    guard let (sessData, _) = try? await URLSession.shared.data(for: sessReq),
          let sessions = try? JSONDecoder().decode([MotoGPRaceSession].self, from: sessData),
          let racSession = sessions.first(where: { $0.type == "RAC" }) else { return [] }

    // Step 2: fetch classification
    guard let classURL = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/session/\(racSession.id)/classification") else { return [] }
    var classReq = URLRequest(url: classURL)
    classReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    guard let (classData, _) = try? await URLSession.shared.data(for: classReq),
          let payload = try? JSONDecoder().decode(MotoGPClassificationPayload.self, from: classData) else { return [] }

    var lines: [RacingResultLine] = []
    var dnfLines: [RacingResultLine] = []
    for entry in payload.classification {
      guard let name = entry.rider?.fullName, !name.isEmpty else { continue }
      let teamID = TeamCatalog.racingTeamID(forDriverName: name, sport: .motoGP)
      if let pos = entry.position {
        lines.append(RacingResultLine(position: pos, driverName: name, teamName: entry.team?.name, timeOrGap: entry.timeOrGap, espnTeamID: teamID))
      } else {
        // DNF/retired — position 0 used as sentinel; widget shows "DNF"
        dnfLines.append(RacingResultLine(position: 0, driverName: name, teamName: entry.team?.name, timeOrGap: nil, espnTeamID: teamID))
      }
    }
    return lines + dnfLines
  }

  /// Fetches the official starting grid for an upcoming MotoGP event.
  /// Uses the undocumented /grid endpoint which returns post-penalty positions.
  /// Returns empty if the grid hasn't been published yet.
  private static func fetchMotoGPQualifyingResults(eventID: String) async -> [RacingResultLine] {
    guard let url = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/event/\(eventID)/category/\(motoGPClassUUID)/grid") else { return [] }
    var req = URLRequest(url: url)
    req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    guard let (data, _) = try? await URLSession.shared.data(for: req),
          let entries = try? JSONDecoder().decode([MotoGPGridEntry].self, from: data),
          !entries.isEmpty else { return [] }

    // Array order IS the grid order (index 0 = pole, index 1 = P2, etc.)
    return entries.enumerated().compactMap { (i, entry) in
      guard let name = entry.rider?.fullName, !name.isEmpty else { return nil }
      return RacingResultLine(
        position: i + 1,
        driverName: name,
        teamName: entry.teamName,
        timeOrGap: nil,
        espnTeamID: TeamCatalog.racingTeamID(forDriverName: name, sport: .motoGP)
      )
    }
  }

  /// Fetches the RAC session date for an upcoming MotoGP event.
  /// The Pulselive API stores session times in circuit-local time but labels the
  /// offset as +00:00, so we strip the offset and re-parse using circuitTimezone.
  private static func fetchMotoGPRaceDate(eventID: String, circuitTimezone: TimeZone?) async -> Date? {
    guard let sessURL = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/sessions?eventUuid=\(eventID)&categoryUuid=\(motoGPClassUUID)") else { return nil }
    var sessReq = URLRequest(url: sessURL)
    sessReq.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
    guard let (sessData, _) = try? await URLSession.shared.data(for: sessReq),
          let sessions = try? JSONDecoder().decode([MotoGPRaceSession].self, from: sessData),
          let racSession = sessions.first(where: { $0.type == "RAC" }),
          let dateStr = racSession.date else { return nil }

    // Strip the fake +00:00 offset and parse as circuit-local time
    let localStr = dateStr.replacingOccurrences(of: "+00:00", with: "")
                          .replacingOccurrences(of: "Z", with: "")
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "en_US_POSIX")
    fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
    fmt.timeZone = circuitTimezone ?? TimeZone(identifier: "UTC")
    return fmt.date(from: localStr)
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

// MARK: - MotoGP live timing Decodable models

private struct MotoGPLiveTimingPayload: Decodable {
  let head: MotoGPLiveTimingHead
  let rider: [String: MotoGPLiveTimingRider]
}

private struct MotoGPLiveTimingHead: Decodable {
  let category: String
  let sessionShortname: String
  let eventShortname: String
  let numLaps: Int?
  let remaining: String?

  enum CodingKeys: String, CodingKey {
    case category
    case sessionShortname = "session_shortname"
    case eventShortname = "event_shortname"
    case numLaps = "num_laps"
    case remaining
  }
}

private struct MotoGPLiveTimingRider: Decodable {
  let pos: Int?
  let riderName: String?
  let riderSurname: String?

  enum CodingKeys: String, CodingKey {
    case pos
    case riderName = "rider_name"
    case riderSurname = "rider_surname"
  }
}

private struct MotoGPSeason: Decodable {
  let id: String
  let current: Bool
}

private struct MotoGPRaceSession: Decodable {
  let id: String
  let type: String
  let date: String?
}

private struct MotoGPGridEntry: Decodable {
  let rider: MotoGPRider?
  let teamName: String?
  enum CodingKeys: String, CodingKey {
    case rider
    case teamName = "team_name"
  }
}

private struct MotoGPClassificationPayload: Decodable {
  let classification: [MotoGPClassEntry]
}

private struct MotoGPClassEntry: Decodable {
  let position: Int?
  let rider: MotoGPRider?
  let team: MotoGPTeamRef?
  let time: String?
  let gap: MotoGPGap?

  struct MotoGPGap: Decodable {
    let first: String?
  }

  /// Human-readable gap: "+5.543" for non-winners, "39:36.270" for winner (gap.first == "0.000").
  var timeOrGap: String? {
    if let f = gap?.first, f != "0.000", !f.isEmpty { return "+\(f)" }
    return time
  }
}

private struct MotoGPRider: Decodable {
  let fullName: String?
  enum CodingKeys: String, CodingKey { case fullName = "full_name" }
}

private struct MotoGPTeamRef: Decodable {
  let name: String?
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

  // MARK: Racing standings

  static func fetchRacing(for team: TeamDefinition) async throws -> HomeTeamTeamSummary? {
    if team.sport == .motoGP { return try await fetchMotoGPStandings(for: team) }
    return try await fetchF1Standings(for: team)
  }

  // MotoGP standings via Pulselive API
  private static func fetchMotoGPStandings(for team: TeamDefinition) async throws -> HomeTeamTeamSummary? {
    let seasonsURL = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/seasons")!
    let (seasonsData, _) = try await URLSession.shared.data(from: seasonsURL)
    let seasons = try JSONDecoder().decode([MotoGPSeason].self, from: seasonsData)
    guard let current = seasons.first(where: { $0.current }) else { return nil }

    let classUUID = "e8c110ad-64aa-4e8e-8a86-f2f152f6a942"
    guard let url = URL(string: "https://api.pulselive.motogp.com/motogp/v1/results/standings?seasonUuid=\(current.id)&categoryUuid=\(classUUID)") else { return nil }
    let (data, _) = try await URLSession.shared.data(from: url)
    let payload = try JSONDecoder().decode(MotoGPStandingsPayload.self, from: data)

    for entry in payload.classification {
      guard let fullName = entry.rider?.fullName else { continue }
      let matches = team.driverNames.contains {
        fullName.lowercased().contains($0.lowercased()) || $0.lowercased().contains(fullName.lowercased())
      }
      guard matches else { continue }
      return HomeTeamTeamSummary(
        compositeID: team.compositeID,
        record: "\(entry.points)",
        place: "\(entry.position)",
        last10: "\(entry.raceWins)",
        streak: "\(entry.podiums)",
        style: .racingDriver
      )
    }
    return nil
  }

  // F1 standings via ESPN API
  private static func fetchF1Standings(for team: TeamDefinition) async throws -> HomeTeamTeamSummary? {
    guard let url = URL(string: "https://site.api.espn.com/apis/v2/sports/racing/\(team.sport.leaguePath)/standings") else { return nil }
    let (data, response) = try await URLSession.shared.data(from: url)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { return nil }
    let payload = try JSONDecoder().decode(RacingStandingsPayload.self, from: data)

    for child in payload.children where child.name.lowercased().contains("driver") {
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

// MARK: - MotoGP standings Decodable models

private struct MotoGPStandingsPayload: Decodable {
  let classification: [MotoGPStandingEntry]
}
private struct MotoGPStandingEntry: Decodable {
  let position: Int
  let rider: MotoGPStandingRider?
  let points: Int
  let raceWins: Int
  let podiums: Int
  enum CodingKeys: String, CodingKey {
    case position, rider, points, podiums
    case raceWins = "race_wins"
  }
}
private struct MotoGPStandingRider: Decodable {
  let fullName: String?
  enum CodingKeys: String, CodingKey { case fullName = "full_name" }
}

// MARK: - F1/ESPN standings Decodable models

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
