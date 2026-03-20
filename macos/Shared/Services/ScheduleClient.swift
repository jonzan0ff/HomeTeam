import Foundation

enum ScheduleClientError: Error {
  case badStatusCode(Int)
  case invalidTeamURL
  case invalidResponse
}

struct ScheduleClient {
  func fetchGames(for team: TeamDefinition) async throws -> [HomeTeamGame] {
    if team.sport == .f1 || team.sport == .motogp {
      return try await fetchRacingGames(for: team)
    }

    let endpoints = scheduleEndpoints(for: team)
    guard !endpoints.isEmpty else {
      throw ScheduleClientError.invalidTeamURL
    }

    var mergedGames: [HomeTeamGame] = []
    for endpoint in endpoints {
      let payload = try await fetchSchedulePayload(from: endpoint)
      mergedGames.append(contentsOf: payload.events.compactMap { $0.asHomeTeamGame(for: team) })
    }

    let deduped = dedupeGames(mergedGames)
    guard team.sport == .nhl else {
      return deduped
    }

    guard deduped.contains(where: { $0.homeRecord == nil || $0.awayRecord == nil }) else {
      return deduped
    }

    let standingsRecords = (try? await NHLStandingsClient.fetchRecordMap()) ?? [:]
    guard !standingsRecords.isEmpty else {
      return deduped
    }

    return deduped.map { game in
      game.fillingMissingRecords(from: standingsRecords)
    }
  }

  func fetchTeamSummary(for team: TeamDefinition) async -> HomeTeamTeamSummary? {
    switch team.sport {
    case .nhl:
      return try? await NHLStandingsClient.fetchTeamSummary(teamAbbreviation: team.abbreviation)
    case .f1:
      return try? await RacingSummaryClient.fetchSummary(for: team)
    case .motogp:
      if let summary = try? await RacingSummaryClient.fetchSummary(for: team) {
        return summary
      }
      return try? await MotoGPPulseLiveClient.fetchSummary(for: team)
    default:
      if let summary = try? await RegularSeasonSummaryClient.fetchSummary(for: team) {
        return summary
      }
      return try? await ScheduleSummaryClient.fetchSummary(for: team)
    }
  }

  private func fetchSchedulePayload(from endpoint: URL) async throws -> EspnScheduleResponse {
    let (data, response) = try await URLSession.shared.data(from: endpoint)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw ScheduleClientError.badStatusCode(http.statusCode)
    }

    return try scheduleDecoder.decode(EspnScheduleResponse.self, from: data)
  }

  private var scheduleDecoder: JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let raw = try container.decode(String.self)

      if let parsed = EspnDateParser.parse(raw) {
        return parsed
      }

      throw DecodingError.dataCorruptedError(
        in: container,
        debugDescription: "Unsupported ESPN date format: \(raw)"
      )
    }
    return decoder
  }

  private func scheduleEndpoints(for team: TeamDefinition) -> [URL] {
    guard let base = team.scheduleURL else {
      return []
    }

    if team.sport != .nfl {
      return [base]
    }

    let now = Date()
    let currentYear = Calendar.current.component(.year, from: now)
    let currentMonth = Calendar.current.component(.month, from: now)
    let activeSeason = currentMonth >= 8 ? currentYear : currentYear - 1
    // Pull both active and previous NFL seasons so offseason and
    // cross-year playoff/regular-season lookups don't drop historical results.
    let seasons = [activeSeason, activeSeason - 1]
    let seasonTypes = [2, 3]

    var urls: [URL] = []
    for season in seasons {
      for seasonType in seasonTypes {
        if let endpoint = Self.appendingQueryItems(
          to: base,
          items: [
            URLQueryItem(name: "season", value: "\(season)"),
            URLQueryItem(name: "seasontype", value: "\(seasonType)"),
          ]
        ) {
          urls.append(endpoint)
        }
      }
    }

    return urls
  }

  private func dedupeGames(_ games: [HomeTeamGame]) -> [HomeTeamGame] {
    var byID: [String: HomeTeamGame] = [:]
    for game in games {
      byID[game.id] = game
    }

    return byID.values.sorted { $0.startTimeUTC < $1.startTimeUTC }
  }

  private static func appendingQueryItems(to url: URL, items: [URLQueryItem]) -> URL? {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return nil
    }

    var merged = components.queryItems ?? []
    merged.append(contentsOf: items)
    components.queryItems = merged
    return components.url
  }

  private func fetchRacingGames(for team: TeamDefinition) async throws -> [HomeTeamGame] {
    if team.sport == .motogp {
      let pulseLiveGames = try await MotoGPPulseLiveClient.fetchGames(for: team)
      if !pulseLiveGames.isEmpty {
        return pulseLiveGames.sorted { $0.startTimeUTC < $1.startTimeUTC }
      }
    }

    let events = try await RacingScoreboardClient.fetchEvents(for: team.sport)

    let scoreboardGames = events.flatMap { event in
      RacingScoreboardClient.homeTeamGames(from: event, selectedDriver: team)
    }
    let sortedScoreboardGames = scoreboardGames.sorted { $0.startTimeUTC < $1.startTimeUTC }

    if team.sport == .motogp, sortedScoreboardGames.isEmpty {
      return try await MotoGPPulseLiveClient.fetchGames(for: team)
    }

    return sortedScoreboardGames
  }
}

private struct EspnScheduleResponse: Decodable {
  let events: [EspnEvent]
  let team: EspnScheduleTeam?
}

private struct EspnScheduleTeam: Decodable {
  let id: String?
  let displayName: String?
  let recordSummary: String?
  let standingSummary: String?
}

private struct EspnEvent: Decodable {
  let id: String?
  let name: String?
  let shortName: String?
  let date: Date?
  let competitions: [EspnCompetition]

  func asHomeTeamGame(for selectedTeam: TeamDefinition) -> HomeTeamGame? {
    guard let competition = competitions.first else {
      return nil
    }

    let startDate = competition.date ?? date ?? .distantPast
    let broadcastLabels = competition.broadcasts.flatMap(\.labels)
    let services = mergeStreamingServices(from: broadcastLabels)
    let status = competition.status.type.state.asGameStatus
    let statusDetail = competition.status.type.shortDetail ?? competition.status.type.detail ?? ""

    if
      let home = competition.competitors.first(where: { $0.homeAway == "home" }),
      let away = competition.competitors.first(where: { $0.homeAway == "away" }),
      let homeName = home.team?.displayName,
      let awayName = away.team?.displayName,
      let homeAbbrev = home.team?.abbreviation,
      let awayAbbrev = away.team?.abbreviation
    {
      return HomeTeamGame(
        id: id ?? "\(awayAbbrev)-\(homeAbbrev)-\(startDate)",
        startTimeUTC: startDate,
        venue: competition.venue?.fullName ?? "TBD",
        status: status,
        statusDetail: statusDetail,
        homeTeam: homeName,
        awayTeam: awayName,
        homeAbbrev: homeAbbrev,
        awayAbbrev: awayAbbrev,
        homeLogoURL: home.team?.bestLogoURL(forDarkBackground: true),
        awayLogoURL: away.team?.bestLogoURL(forDarkBackground: true),
        homeScore: status == .scheduled ? nil : home.score?.value,
        awayScore: status == .scheduled ? nil : away.score?.value,
        homeRecord: home.displayRecord,
        awayRecord: away.displayRecord,
        streamingServices: services,
        sport: selectedTeam.sport
      )
    }

    if selectedTeam.sport == .f1 || selectedTeam.sport == .motogp {
      let driver = competition.competitors.first(where: { $0.matches(driver: selectedTeam) })
      let competitorCount = competition.competitors.count
      let position = driver?.order
      let eventLabel = shortName ?? name ?? "Race"

      return HomeTeamGame(
        id: id ?? "\(selectedTeam.id)-\(startDate)",
        startTimeUTC: startDate,
        venue: competition.venue?.fullName ?? eventLabel,
        status: status,
        statusDetail: statusDetail,
        homeTeam: eventLabel,
        awayTeam: selectedTeam.displayName,
        homeAbbrev: eventLabel.racingEventAbbreviation,
        awayAbbrev: selectedTeam.abbreviation,
        homeLogoURL: nil,
        awayLogoURL: nil,
        homeScore: status == .scheduled ? nil : competitorCount,
        awayScore: status == .scheduled ? nil : position,
        homeRecord: nil,
        awayRecord: position.map { "P\($0)" },
        streamingServices: services,
        sport: selectedTeam.sport
      )
    }

    return nil
  }

  private func mergeStreamingServices(from broadcastLabels: [String]) -> [String] {
    let matched = StreamingServiceMatcher.matchedServices(from: broadcastLabels)

    var ordered = matched
    var seen = Set(ordered.map(AppSettings.normalizedServiceName))

    for label in broadcastLabels {
      let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cleaned.isEmpty else {
        continue
      }

      let normalized = AppSettings.normalizedServiceName(cleaned)
      if seen.insert(normalized).inserted {
        ordered.append(cleaned)
      }
    }

    return ordered
  }
}

private struct EspnCompetition: Decodable {
  let date: Date?
  let venue: EspnVenue?
  let status: EspnStatus
  let competitors: [EspnCompetitor]
  let broadcasts: [EspnBroadcast]

  enum CodingKeys: String, CodingKey {
    case date
    case venue
    case status
    case competitors
    case broadcasts
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    date = try container.decodeIfPresent(Date.self, forKey: .date)
    venue = try container.decodeIfPresent(EspnVenue.self, forKey: .venue)
    status = try container.decode(EspnStatus.self, forKey: .status)
    competitors = try container.decode([EspnCompetitor].self, forKey: .competitors)
    broadcasts = try container.decodeIfPresent([EspnBroadcast].self, forKey: .broadcasts) ?? []
  }
}

private struct EspnVenue: Decodable {
  let fullName: String?
}

private struct EspnStatus: Decodable {
  let type: EspnStatusType

  enum CodingKeys: String, CodingKey {
    case type
  }

  init(type: EspnStatusType) {
    self.type = type
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    type = try container.decodeIfPresent(EspnStatusType.self, forKey: .type) ?? EspnStatusType()
  }
}

private struct EspnStatusType: Decodable {
  let state: String?
  let detail: String?
  let shortDetail: String?

  init(state: String? = nil, detail: String? = nil, shortDetail: String? = nil) {
    self.state = state
    self.detail = detail
    self.shortDetail = shortDetail
  }
}

private struct EspnCompetitor: Decodable {
  let id: String?
  let order: Int?
  let homeAway: String?
  let team: EspnTeam?
  let athlete: EspnAthlete?
  let score: EspnScore?
  let record: [EspnRecord]?
  let winner: Bool?
}

private struct EspnAthlete: Decodable {
  let id: String?
  let displayName: String?
  let shortName: String?
  let abbreviation: String?
}

private struct EspnRecord: Decodable {
  let type: String?
  let displayValue: String?
}

private struct EspnTeam: Decodable {
  struct EspnLogo: Decodable {
    let href: String?
    let rel: [String]?
  }

  let displayName: String?
  let abbreviation: String?
  let logos: [EspnLogo]?

  func bestLogoURL(forDarkBackground: Bool) -> String? {
    let logos = logos ?? []

    if forDarkBackground, let dark = logos.first(where: { ($0.rel ?? []).contains("dark") })?.href {
      return dark
    }

    if let scoreboard = logos.first(where: { ($0.rel ?? []).contains("scoreboard") })?.href {
      if forDarkBackground, abbreviation == "WSH" {
        return scoreboard.replacingOccurrences(of: "/500/", with: "/500-dark/")
      }
      return scoreboard
    }

    if let defaultLogo = logos.first(where: { ($0.rel ?? []).contains("default") })?.href {
      if forDarkBackground, abbreviation == "WSH" {
        return defaultLogo.replacingOccurrences(of: "/500/", with: "/500-dark/")
      }
      return defaultLogo
    }

    return logos.first?.href
  }
}

private struct EspnScore: Decodable {
  let value: Int?

  enum CodingKeys: String, CodingKey {
    case value
    case displayValue
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    value = Self.decodeInt(from: container)
  }

  private static func decodeInt(from container: KeyedDecodingContainer<CodingKeys>) -> Int? {
    if let intValue = try? container.decodeIfPresent(Int.self, forKey: .value) {
      return intValue
    }

    if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: .value) {
      return Int(doubleValue.rounded())
    }

    if let stringValue = try? container.decodeIfPresent(String.self, forKey: .value) {
      return Int(stringValue) ?? Double(stringValue).map { Int($0.rounded()) }
    }

    if let display = try? container.decodeIfPresent(String.self, forKey: .displayValue) {
      return Int(display)
    }

    return nil
  }
}

private struct EspnBroadcast: Decodable {
  let media: EspnMedia?
  let names: [String]

  enum CodingKeys: String, CodingKey {
    case media
    case names
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    media = try container.decodeIfPresent(EspnMedia.self, forKey: .media)
    names = Self.decodeNames(from: container)
  }

  private static func decodeNames(from container: KeyedDecodingContainer<CodingKeys>) -> [String] {
    if let values = try? container.decode([String].self, forKey: .names) {
      return values
    }

    if let value = try? container.decode(String.self, forKey: .names) {
      return [value]
    }

    return []
  }

  var labels: [String] {
    var results = names
    if let shortName = media?.shortName, !shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      results.append(shortName)
    }
    return results
  }
}

private struct EspnMedia: Decodable {
  let shortName: String?
}

private extension EspnCompetitor {
  var displayRecord: String? {
    let home = record?.first(where: { $0.type == "home" })?.displayValue
    let away = record?.first(where: { $0.type == "road" || $0.type == "away" })?.displayValue
    if let combined = combineHomeAwayRecord(home: home, away: away) {
      return combined
    }

    if
      let ytdValue = record?.first(where: { $0.type == "ytd" })?.displayValue,
      let ytd = ytdValue.recordCore
    {
      return ytd
    }

    if
      let fallback = record?.first?.displayValue,
      let core = fallback.recordCore
    {
      return core
    }

    return nil
  }

  private func combineHomeAwayRecord(home: String?, away: String?) -> String? {
    guard
      let homeParts = parseRecordTriplet(home),
      let awayParts = parseRecordTriplet(away)
    else {
      return nil
    }

    return "\(homeParts.0 + awayParts.0)-\(homeParts.1 + awayParts.1)-\(homeParts.2 + awayParts.2)"
  }

  private func parseRecordTriplet(_ value: String?) -> (Int, Int, Int)? {
    guard
      let value,
      let core = value.recordCore
    else {
      return nil
    }

    let parts = core.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3 else {
      return nil
    }

    return (parts[0], parts[1], parts[2])
  }

  func matches(driver: TeamDefinition) -> Bool {
    if let id, id == driver.id {
      return true
    }

    if let athleteID = athlete?.id, athleteID == driver.id {
      return true
    }

    let candidateNames = [athlete?.displayName, athlete?.shortName].compactMap { $0 }
    let targetNames = [driver.city, driver.displayName]
    for candidate in candidateNames {
      if targetNames.contains(where: { candidate.matchesPersonName($0) }) {
        return true
      }
    }

    return false
  }
}

private extension String? {
  var asGameStatus: GameStatus {
    switch self {
    case "in": return .live
    case "post": return .final
    default: return .scheduled
    }
  }

}

private extension String {
  var normalizedPersonName: String {
    lowercased()
      .replacingOccurrences(of: "-", with: " ")
      .replacingOccurrences(of: ".", with: "")
      .split(separator: " ")
      .map(String.init)
      .joined(separator: " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  func matchesPersonName(_ other: String) -> Bool {
    let lhs = normalizedPersonName
    let rhs = other.normalizedPersonName
    guard !lhs.isEmpty, !rhs.isEmpty else {
      return false
    }

    if lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs) {
      return true
    }

    let lhsTokens = lhs.split(separator: " ").map(String.init)
    let rhsTokens = rhs.split(separator: " ").map(String.init)
    guard
      let lhsLast = lhsTokens.last,
      let rhsLast = rhsTokens.last,
      lhsLast == rhsLast,
      let lhsFirst = lhsTokens.first,
      let rhsFirst = rhsTokens.first
    else {
      return false
    }

    if lhsFirst == rhsFirst {
      return true
    }

    return lhsFirst.first == rhsFirst.first
  }

  var racingEventAbbreviation: String {
    let tokens = self
      .replacingOccurrences(of: "-", with: " ")
      .split(separator: " ")
      .map(String.init)
      .filter { !$0.isEmpty }

    let initials = tokens.prefix(3).compactMap { $0.first.map(String.init) }.joined().uppercased()
    return initials.isEmpty ? "RACE" : initials
  }

  var recordCore: String? {
    let firstSegment = self.split(separator: ",", maxSplits: 1).first?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let core = firstSegment, !core.isEmpty else {
      return nil
    }

    return core
  }
}

private enum RegularSeasonSummaryClient {
  static func fetchSummary(for team: TeamDefinition) async throws -> HomeTeamTeamSummary? {
    let currentYear = Calendar.current.component(.year, from: Date())
    for season in [currentYear, currentYear - 1] {
      if let summary = try await fetchSummary(for: team, season: season) {
        return summary
      }
    }
    return nil
  }

  private static func fetchSummary(for team: TeamDefinition, season: Int) async throws -> HomeTeamTeamSummary? {
    guard var components = URLComponents(string: "https://site.api.espn.com/apis/v2/sports/\(team.sport.sportPath)/\(team.sport.leaguePath)/standings") else {
      return nil
    }

    components.queryItems = [
      URLQueryItem(name: "season", value: "\(season)"),
      URLQueryItem(name: "seasontype", value: "2"),
    ]

    guard let url = components.url else {
      return nil
    }

    let (data, response) = try await URLSession.shared.data(from: url)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw ScheduleClientError.badStatusCode(http.statusCode)
    }

    let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
    return findSummary(in: jsonObject, teamID: team.id, context: [])
  }

  private static func findSummary(in node: Any, teamID: String, context: [String]) -> HomeTeamTeamSummary? {
    if let dict = node as? [String: Any] {
      var currentContext = context
      if let name = dict["name"] as? String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
          currentContext.append(trimmed)
        }
      }

      if let entries = dict["entries"] as? [[String: Any]] {
        for entry in entries {
          guard
            let team = entry["team"] as? [String: Any],
            let id = team["id"] as? String,
            id == teamID
          else {
            continue
          }

          return summary(from: entry, context: currentContext)
        }
      }

      if let standings = dict["standings"] {
        if let summary = findSummary(in: standings, teamID: teamID, context: currentContext) {
          return summary
        }
      }

      if let children = dict["children"] as? [Any] {
        for child in children {
          if let summary = findSummary(in: child, teamID: teamID, context: currentContext) {
            return summary
          }
        }
      }
    } else if let array = node as? [Any] {
      for item in array {
        if let summary = findSummary(in: item, teamID: teamID, context: context) {
          return summary
        }
      }
    }

    return nil
  }

  private static func summary(from entry: [String: Any], context: [String]) -> HomeTeamTeamSummary {
    let statsArray = entry["stats"] as? [[String: Any]] ?? []
    var stats: [String: String] = [:]

    for stat in statsArray {
      guard
        let name = stat["name"] as? String,
        let value = stat["displayValue"] as? String,
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        continue
      }
      stats[name.lowercased()] = value
    }

    let wins = stats["wins"]
    let losses = stats["losses"]
    let ties = stats["ties"]
    let overall = stats["overall"] ?? stats["record"]
    let record = overall ?? composedRecord(wins: wins, losses: losses, ties: ties) ?? "-"

    let rawRank = stats["rank"] ?? stats["playoffseed"] ?? stats["position"]
    let groupName = context.last ?? "Standings"
    let place: String
    if let rawRank, let rank = Int(rawRank) {
      place = "\(ordinal(rank)) in \(groupName)"
    } else {
      place = rawRank ?? groupName
    }

    let last10 = stats["lastten"] ?? stats["last10"] ?? stats["l10"] ?? "-"
    let streak = stats["streak"] ?? "-"

    return HomeTeamTeamSummary(record: record, place: place, last10: last10, streak: streak, style: .standard)
  }

  private static func composedRecord(wins: String?, losses: String?, ties: String?) -> String? {
    guard let wins, let losses else {
      return nil
    }

    if let ties, ties != "0" {
      return "\(wins)-\(losses)-\(ties)"
    }

    return "\(wins)-\(losses)"
  }

  private static func ordinal(_ value: Int) -> String {
    let tens = value % 100
    if tens == 11 || tens == 12 || tens == 13 {
      return "\(value)th"
    }

    switch value % 10 {
    case 1: return "\(value)st"
    case 2: return "\(value)nd"
    case 3: return "\(value)rd"
    default: return "\(value)th"
    }
  }
}

private enum ScheduleSummaryClient {
  static func fetchSummary(for team: TeamDefinition) async throws -> HomeTeamTeamSummary? {
    guard let endpoint = team.scheduleURL else {
      return nil
    }

    let currentYear = Calendar.current.component(.year, from: Date())
    for season in [currentYear, currentYear - 1] {
      guard let url = appendingSeasonQuery(to: endpoint, season: season) else {
        continue
      }

      let (data, response) = try await URLSession.shared.data(from: url)
      if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
        continue
      }

      let payload = try JSONDecoder().decode(EspnScheduleResponse.self, from: data)
      let record = payload.team?.recordSummary?.recordCore ?? payload.team?.recordSummary ?? "-"
      let place = payload.team?.standingSummary ?? "Regular Season"

      if record != "-" || place != "Regular Season" {
        return HomeTeamTeamSummary(record: record, place: place, last10: "-", streak: "-", style: .standard)
      }
    }

    return nil
  }

  private static func appendingSeasonQuery(to url: URL, season: Int) -> URL? {
    guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return nil
    }
    components.queryItems = [
      URLQueryItem(name: "season", value: "\(season)"),
      URLQueryItem(name: "seasontype", value: "2"),
    ]
    return components.url
  }
}

private enum RacingScoreboardClient {
  private struct RacingTeamIdentity {
    let teamName: String
    let teamAbbrev: String
    let teamLogoURL: String?
  }

  static func fetchEvents(for sport: SupportedSport) async throws -> [EspnRacingEvent] {
    let year = Calendar.current.component(.year, from: Date())
    let endpoints = scoreboardEndpoints(for: sport, year: year)
    let decoder = makeRacingDecoder()

    var merged: [EspnRacingEvent] = []
    for endpoint in endpoints {
      do {
        let (data, response) = try await URLSession.shared.data(from: endpoint)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
          continue
        }

        let payload = try decoder.decode(EspnRacingScoreboardPayload.self, from: data)
        if !payload.events.isEmpty {
          merged.append(contentsOf: payload.events)
        }
      } catch {
        continue
      }
    }

    let deduped = dedupeEvents(merged)
    return filterEventsForActiveSeason(deduped)
  }

  static func homeTeamGames(from event: EspnRacingEvent, selectedDriver: TeamDefinition) -> [HomeTeamGame] {
    let competitions = competitionCandidates(in: event, sport: selectedDriver.sport)
    return competitions.compactMap { competition in
      homeTeamGame(from: event, competition: competition, selectedDriver: selectedDriver)
    }
  }

  static func homeTeamGame(from event: EspnRacingEvent, selectedDriver: TeamDefinition) -> HomeTeamGame? {
    homeTeamGames(from: event, selectedDriver: selectedDriver).first
  }

  private static func homeTeamGame(
    from event: EspnRacingEvent,
    competition raceCompetition: EspnRacingCompetition,
    selectedDriver: TeamDefinition
  ) -> HomeTeamGame? {
    let raceStartDate = raceCompetition.date ?? event.date ?? .distantPast
    let raceStatus = raceCompetition.status.type.state.asGameStatus
    let raceHasResults = hasOrderedResults(in: raceCompetition)
    let qualifyingCompetition = preferredQualifyingCompetition(in: event)
    let qualifyingHasResults = hasOrderedResults(in: qualifyingCompetition)

    let status: GameStatus = {
      if raceStartDate > Date(), raceStatus != .live {
        return .scheduled
      }

      if raceStatus == .final, !raceHasResults {
        return .scheduled
      }

      return raceStatus
    }()

    let rankingCompetition: EspnRacingCompetition? = {
      if status == .final, raceHasResults {
        return raceCompetition
      }

      if
        status == .scheduled,
        let qualifyingCompetition,
        qualifyingCompetition.status.type.state.asGameStatus == .final,
        qualifyingHasResults
      {
        return qualifyingCompetition
      }

      return nil
    }()

    let driver = (rankingCompetition?.competitors ?? raceCompetition.competitors).first { competitor in
      competitor.matches(driver: selectedDriver)
    }

    let statusDetail = raceCompetition.status.type.shortDetail ?? raceCompetition.status.type.detail ?? ""
    let eventLabel = competitionDisplayLabel(
      event: event,
      competition: raceCompetition,
      sport: selectedDriver.sport
    )
    let streams = raceCompetition.broadcasts.flatMap(\.labels)
    let services = mergeStreamingServices(from: streams)
    let favoriteIdentity = driver.flatMap { teamIdentity(for: $0, sport: selectedDriver.sport) }
      ?? teamIdentity(for: selectedDriver)

    var racingResults: [RacingResultLine]? = nil
    if let rankingCompetition {
      let sortedCompetitors = rankingCompetition.competitors
        .filter { $0.order != nil }
        .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
      let podiumLines = sortedCompetitors.prefix(3).compactMap { resultLine(for: $0, selectedDriver: selectedDriver) }
      var lines: [RacingResultLine] = podiumLines

      if
        let driver,
        let place = driver.order,
        place > 3,
        let favoriteLine = resultLine(for: driver, selectedDriver: selectedDriver)
      {
        lines.append(favoriteLine)
      }

      racingResults = lines.isEmpty ? nil : lines
    }

    let showFavoriteIdentity = status != .scheduled || racingResults != nil
    let competitionID = gameIdentifierComponent(for: raceCompetition)

    return HomeTeamGame(
      id: "\(event.id)-\(competitionID)-\(selectedDriver.id)",
      startTimeUTC: raceStartDate,
      venue: raceCompetition.venue?.fullName ?? eventLabel,
      status: status,
      statusDetail: statusDetail,
      homeTeam: eventLabel,
      awayTeam: selectedDriver.displayName,
      homeAbbrev: status == .scheduled ? "" : eventLabel.racingEventAbbreviation,
      awayAbbrev: showFavoriteIdentity ? selectedDriver.abbreviation : "",
      homeLogoURL: nil,
      awayLogoURL: showFavoriteIdentity ? favoriteIdentity.teamLogoURL : nil,
      homeScore: status == .final ? raceCompetition.competitors.count : nil,
      awayScore: status == .final ? driver?.order : nil,
      homeRecord: nil,
      awayRecord: status == .final ? driver?.order.map { "P\($0)" } : nil,
      streamingServices: services,
      sport: selectedDriver.sport,
      racingResults: racingResults
    )
  }

  private static func competitionCandidates(
    in event: EspnRacingEvent,
    sport: SupportedSport
  ) -> [EspnRacingCompetition] {
    if sport == .motogp {
      let scoringCompetitions = event.competitions
        .filter(isMotoGPScoringCompetition)
        .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
      if !scoringCompetitions.isEmpty {
        return scoringCompetitions
      }
    }

    if let preferred = preferredCompetition(in: event, sport: sport) {
      return [preferred]
    }

    return []
  }

  private static func competitionDisplayLabel(
    event: EspnRacingEvent,
    competition: EspnRacingCompetition,
    sport: SupportedSport
  ) -> String {
    let base = event.shortName ?? event.name ?? "Race"
    guard sport == .motogp else {
      return base
    }

    if isMotoGPSprintCompetition(competition) {
      if base.lowercased().contains("sprint") {
        return base
      }
      return "\(base) Sprint"
    }

    return base
  }

  private static func gameIdentifierComponent(for competition: EspnRacingCompetition) -> String {
    if let id = competition.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
      return id
    }

    let abbreviation = competition.type?.abbreviation?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "session"
    let text = competition.type?.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    if !text.isEmpty {
      return "\(abbreviation)-\(text.replacingOccurrences(of: " ", with: "-"))"
    }

    if let date = competition.date {
      return "\(abbreviation)-\(Int(date.timeIntervalSince1970))"
    }

    return abbreviation
  }

  static func preferredCompetition(in event: EspnRacingEvent, sport: SupportedSport) -> EspnRacingCompetition? {
    let competitions = event.competitions
    guard !competitions.isEmpty else {
      return nil
    }

    if let race = competitions.first(where: { isGrandPrixCompetition($0, sport: sport) }) {
      return race
    }

    // Fallback to the chronologically latest competition when the API omits
    // clear race typing.
    return competitions.max { lhs, rhs in
      (lhs.date ?? .distantPast) < (rhs.date ?? .distantPast)
    }
  }

  private static func isGrandPrixCompetition(_ competition: EspnRacingCompetition, sport: SupportedSport) -> Bool {
    let abbreviation = competition.type?.abbreviation?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    let text = competition.type?.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

    if sport == .f1 {
      if abbreviation == "race" || abbreviation == "r" || abbreviation == "rac" {
        return true
      }
      if text.contains("race") || text.contains("grand prix") {
        return true
      }
      return false
    }

    if sport == .motogp {
      if abbreviation == "rac" || abbreviation == "race" || abbreviation == "r" || abbreviation == "gp" {
        return true
      }
      if text.contains("grand prix") || text == "race" || text.contains("main race") {
        return true
      }
      return false
    }

    return false
  }

  private static func isMotoGPSprintCompetition(_ competition: EspnRacingCompetition) -> Bool {
    let abbreviation = competition.type?.abbreviation?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    let text = competition.type?.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

    if abbreviation == "spr" || abbreviation == "sprint" || abbreviation == "sp" {
      return true
    }

    return text.contains("sprint")
  }

  private static func isMotoGPScoringCompetition(_ competition: EspnRacingCompetition) -> Bool {
    isMotoGPSprintCompetition(competition) || isGrandPrixCompetition(competition, sport: .motogp)
  }

  private static func preferredQualifyingCompetition(in event: EspnRacingEvent) -> EspnRacingCompetition? {
    let qualifying = event.competitions.filter(isQualifyingCompetition)
    guard !qualifying.isEmpty else {
      return nil
    }

    return qualifying.max { lhs, rhs in
      (lhs.date ?? .distantPast) < (rhs.date ?? .distantPast)
    }
  }

  private static func isQualifyingCompetition(_ competition: EspnRacingCompetition) -> Bool {
    let abbreviation = competition.type?.abbreviation?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    let text = competition.type?.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

    if abbreviation == "qual" || abbreviation == "q" || abbreviation == "quali" {
      return true
    }

    if text.contains("qualif") {
      return true
    }

    return false
  }

  private static func hasOrderedResults(in competition: EspnRacingCompetition?) -> Bool {
    guard let competition else {
      return false
    }

    return competition.competitors.contains { ($0.order ?? 0) > 0 }
  }

  private static func resultLine(for competitor: EspnCompetitor, selectedDriver: TeamDefinition) -> RacingResultLine? {
    guard
      let place = competitor.order,
      place > 0
    else {
      return nil
    }

    let identity = teamIdentity(for: competitor, sport: selectedDriver.sport)
    let teamName = identity?.teamName ?? "Team"
    let driverName = competitor.athlete?.shortName ?? competitor.athlete?.displayName ?? "Driver"
    let teamAbbrev = identity?.teamAbbrev ?? RacingTeamLogoCatalog.teamAbbreviation(for: teamName, sport: selectedDriver.sport)
    let teamLogoURL = identity?.teamLogoURL ?? RacingTeamLogoCatalog.logoURL(for: teamName, sport: selectedDriver.sport)

    return RacingResultLine(
      place: place,
      driver: driverName,
      team: teamName,
      teamAbbrev: teamAbbrev,
      teamLogoURL: teamLogoURL,
      isFavorite: competitor.matches(driver: selectedDriver)
    )
  }

  private static func teamIdentity(for competitor: EspnCompetitor, sport: SupportedSport) -> RacingTeamIdentity? {
    if
      let teamName = competitor.team?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
      !teamName.isEmpty
    {
      return RacingTeamIdentity(
        teamName: teamName,
        teamAbbrev: RacingTeamLogoCatalog.teamAbbreviation(for: teamName, sport: sport),
        teamLogoURL: competitor.team?.bestLogoURL(forDarkBackground: true) ?? RacingTeamLogoCatalog.logoURL(for: teamName, sport: sport)
      )
    }

    if let mappedDriver = TeamCatalog.teams(for: sport).first(where: { competitor.matches(driver: $0) }) {
      return RacingTeamIdentity(
        teamName: mappedDriver.name,
        teamAbbrev: RacingTeamLogoCatalog.teamAbbreviation(for: mappedDriver.name, sport: sport),
        teamLogoURL: RacingTeamLogoCatalog.logoURL(for: mappedDriver.name, sport: sport)
      )
    }

    return nil
  }

  private static func teamIdentity(for driver: TeamDefinition) -> RacingTeamIdentity {
    let teamName = driver.name
    return RacingTeamIdentity(
      teamName: teamName,
      teamAbbrev: RacingTeamLogoCatalog.teamAbbreviation(for: teamName, sport: driver.sport),
      teamLogoURL: RacingTeamLogoCatalog.logoURL(for: teamName, sport: driver.sport)
    )
  }

  private static func scoreboardEndpoints(for sport: SupportedSport, year: Int) -> [URL] {
    var urls: [URL] = []

    if var components = URLComponents(string: "https://site.api.espn.com/apis/site/v2/sports/racing/\(sport.leaguePath)/scoreboard") {
      let previousRange = "\(year - 1)0101-\(year - 1)1231"
      let currentRange = "\(year)0101-\(year)1231"
      let nextRange = "\(year + 1)0101-\(year + 1)1231"
      for range in [previousRange, currentRange, nextRange, "\(year - 1)0101-\(year + 1)1231"] {
        components.queryItems = [URLQueryItem(name: "dates", value: range)]
        if let url = components.url {
          urls.append(url)
        }
      }
    }

    if var fallback = URLComponents(string: "https://site.api.espn.com/apis/v2/sports/racing/\(sport.leaguePath)/scoreboard") {
      fallback.queryItems = [URLQueryItem(name: "limit", value: "300")]
      if let url = fallback.url {
        urls.append(url)
      }
    }

    return urls
  }

  private static func makeRacingDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      let raw = try container.decode(String.self)
      if let parsed = EspnDateParser.parse(raw) {
        return parsed
      }
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported ESPN date format: \(raw)")
    }
    return decoder
  }

  private static func dedupeEvents(_ events: [EspnRacingEvent]) -> [EspnRacingEvent] {
    var byID: [String: EspnRacingEvent] = [:]
    for event in events {
      byID[event.id] = event
    }

    return byID.values.sorted { lhs, rhs in
      lhs.referenceDate < rhs.referenceDate
    }
  }

  private static func filterEventsForActiveSeason(_ events: [EspnRacingEvent], now: Date = Date()) -> [EspnRacingEvent] {
    guard !events.isEmpty else {
      return []
    }

    let sorted = events.sorted { $0.referenceDate < $1.referenceDate }
    let anchorDate = sorted.first(where: { $0.referenceDate >= now })?.referenceDate
      ?? sorted.last(where: { $0.referenceDate <= now })?.referenceDate
      ?? sorted.last?.referenceDate
      ?? now
    let calendar = Calendar(identifier: .gregorian)
    let seasonYear = calendar.component(.year, from: anchorDate)

    let filtered = sorted.filter { event in
      calendar.component(.year, from: event.referenceDate) == seasonYear
    }

    return filtered.isEmpty ? sorted : filtered
  }

  private static func mergeStreamingServices(from broadcastLabels: [String]) -> [String] {
    let matched = StreamingServiceMatcher.matchedServices(from: broadcastLabels)

    var ordered = matched
    var seen = Set(ordered.map(AppSettings.normalizedServiceName))

    for label in broadcastLabels {
      let cleaned = label.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !cleaned.isEmpty else {
        continue
      }

      let normalized = AppSettings.normalizedServiceName(cleaned)
      if seen.insert(normalized).inserted {
        ordered.append(cleaned)
      }
    }

    return ordered
  }
}

private enum RacingTeamLogoCatalog {
  private static let f1TeamLogos: [String: String] = [
    "mercedes": brandLogoURL(domain: "mercedesamgf1.com"),
    "mercedes-amg petronas": brandLogoURL(domain: "mercedesamgf1.com"),
    "mercedes amg petronas": brandLogoURL(domain: "mercedesamgf1.com"),
    "ferrari": brandLogoURL(domain: "ferrari.com"),
    "scuderia ferrari hp": brandLogoURL(domain: "ferrari.com"),
    "mclaren": brandLogoURL(domain: "mclaren.com"),
    "red bull": brandLogoURL(domain: "redbullracing.com"),
    "red bull racing": brandLogoURL(domain: "redbullracing.com"),
    "oracle red bull racing": brandLogoURL(domain: "redbullracing.com"),
    "racing bulls": brandLogoURL(domain: "racingbulls.com"),
    "visa cash app racing bulls": brandLogoURL(domain: "racingbulls.com"),
    "visa cash app rb": brandLogoURL(domain: "racingbulls.com"),
    "williams": brandLogoURL(domain: "williamsf1.com"),
    "atlassian williams racing": brandLogoURL(domain: "williamsf1.com"),
    "haas": brandLogoURL(domain: "haasf1team.com"),
    "moneygram haas f1 team": brandLogoURL(domain: "haasf1team.com"),
    "alpine": brandLogoURL(domain: "alpinecars.com"),
    "bwt alpine": brandLogoURL(domain: "alpinecars.com"),
    "audi": brandLogoURL(domain: "audi.com"),
    "audi f1 team": brandLogoURL(domain: "audi.com"),
    "aston martin": brandLogoURL(domain: "astonmartinf1.com"),
    "aston martin aramco": brandLogoURL(domain: "astonmartinf1.com"),
    "cadillac": brandLogoURL(domain: "cadillac.com"),
    "cadillac f1 team": brandLogoURL(domain: "cadillac.com"),
    "kick sauber": brandLogoURL(domain: "sauber-group.com"),
    "stake f1 team kick sauber": brandLogoURL(domain: "sauber-group.com"),
    "sauber": brandLogoURL(domain: "sauber-group.com"),
  ]

  private static let motogpTeamLogos: [String: String] = [
    "ducati": faviconURL(domain: "ducati.com"),
    "aprilia": faviconURL(domain: "aprilia.com"),
    "ktm": faviconURL(domain: "ktm.com"),
    "yamaha": faviconURL(domain: "yamaha-motor.com"),
    "honda": faviconURL(domain: "honda.com"),
  ]

  private static let f1Abbreviations: [String: String] = [
    "mercedes": "MER",
    "mercedes-amg petronas": "MER",
    "mercedes amg petronas": "MER",
    "ferrari": "FER",
    "scuderia ferrari hp": "FER",
    "mclaren": "MCL",
    "red bull": "RBR",
    "red bull racing": "RBR",
    "oracle red bull racing": "RBR",
    "racing bulls": "RB",
    "visa cash app racing bulls": "RB",
    "visa cash app rb": "RB",
    "williams": "WIL",
    "atlassian williams racing": "WIL",
    "haas": "HAA",
    "moneygram haas f1 team": "HAA",
    "alpine": "ALP",
    "bwt alpine": "ALP",
    "audi": "AUD",
    "audi f1 team": "AUD",
    "aston martin": "AST",
    "aston martin aramco": "AST",
    "cadillac": "CAD",
    "cadillac f1 team": "CAD",
    "kick sauber": "SAU",
    "stake f1 team kick sauber": "SAU",
    "sauber": "SAU",
  ]

  private static let motogpAbbreviations: [String: String] = [
    "ducati": "DUC",
    "aprilia": "APR",
    "ktm": "KTM",
    "yamaha": "YAM",
    "honda": "HON",
  ]

  static func logoURL(for teamName: String, sport: SupportedSport) -> String? {
    let normalizedName = normalized(teamName)
    switch sport {
    case .f1:
      if let key = resolvedKey(for: normalizedName, in: Array(f1TeamLogos.keys)) {
        return f1TeamLogos[key]
      }
      return nil
    case .motogp:
      if let key = resolvedKey(for: normalizedName, in: Array(motogpTeamLogos.keys)) {
        return motogpTeamLogos[key]
      }
      return nil
    default:
      return nil
    }
  }

  static func teamAbbreviation(for teamName: String, sport: SupportedSport) -> String {
    let normalizedName = normalized(teamName)
    switch sport {
    case .f1:
      if let key = resolvedKey(for: normalizedName, in: Array(f1Abbreviations.keys)), let value = f1Abbreviations[key] {
        return value
      }
    case .motogp:
      if let key = resolvedKey(for: normalizedName, in: Array(motogpAbbreviations.keys)), let value = motogpAbbreviations[key] {
        return value
      }
    default:
      break
    }

    let compact = normalizedName.replacingOccurrences(of: " ", with: "")
    return String(compact.prefix(3)).uppercased()
  }

  private static func normalized(_ teamName: String) -> String {
    teamName
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: "&", with: " and ")
      .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func faviconURL(domain: String) -> String {
    "https://www.google.com/s2/favicons?domain=\(domain)&sz=64"
  }

  private static func brandLogoURL(domain: String) -> String {
    faviconURL(domain: domain)
  }

  private static func resolvedKey(for normalizedName: String, in keys: [String]) -> String? {
    let normalizedPairs = keys.map { raw in
      (raw: raw, normalized: normalized(raw))
    }

    if let exact = normalizedPairs.first(where: { $0.normalized == normalizedName }) {
      return exact.raw
    }

    if let containsMatch = normalizedPairs.first(where: {
      normalizedName.contains($0.normalized) || $0.normalized.contains(normalizedName)
    }) {
      return containsMatch.raw
    }

    return nil
  }
}

private enum RacingSummaryClient {
  static func fetchSummary(for team: TeamDefinition) async throws -> HomeTeamTeamSummary? {
    guard let standings = try await fetchDriverStanding(for: team) else {
      return nil
    }

    let events = (try? await RacingScoreboardClient.fetchEvents(for: team.sport)) ?? []
    var wins = 0
    var podiums = 0

    for event in events {
      guard let competition = RacingScoreboardClient.preferredCompetition(in: event, sport: team.sport) else {
        continue
      }

      guard competition.status.type.state.asGameStatus == .final else {
        continue
      }

      guard let competitor = competition.competitors.first(where: { $0.matches(driver: team) }) else {
        continue
      }

      if competitor.order == 1 {
        wins += 1
      }
      if let order = competitor.order, order <= 3 {
        podiums += 1
      }
    }

    let points = standings["championshippts"] ?? standings["points"] ?? "-"
    let place = standings["rank"] ?? standings["position"] ?? "-"
    return HomeTeamTeamSummary(
      record: points,
      place: place,
      last10: "\(wins)",
      streak: "\(podiums)",
      style: .racingDriver
    )
  }

  private static func fetchDriverStanding(for team: TeamDefinition) async throws -> [String: String]? {
    guard let endpoint = URL(string: "https://site.api.espn.com/apis/v2/sports/racing/\(team.sport.leaguePath)/standings") else {
      return nil
    }

    let (data, response) = try await URLSession.shared.data(from: endpoint)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw ScheduleClientError.badStatusCode(http.statusCode)
    }

    let payload = try JSONDecoder().decode(EspnRacingStandingsPayload.self, from: data)
    for child in payload.children {
      guard child.name.lowercased().contains("driver") else {
        continue
      }

      for entry in child.standings.entries where entry.matches(driver: team) {
        var stats: [String: String] = [:]
        for stat in entry.stats {
          let key = stat.name.lowercased()
          let value = stat.displayValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
          if !value.isEmpty {
            stats[key] = value
          }
        }
        if !stats.isEmpty {
          return stats
        }
      }
    }

    return nil
  }
}

private enum MotoGPPulseLiveClient {
  private static let baseURL = "https://api.motogp.pulselive.com/motogp/v1/results"

  static func fetchGames(for team: TeamDefinition) async throws -> [HomeTeamGame] {
    guard team.sport == .motogp else {
      return []
    }

    let context: (seasonID: String, categoryID: String)
    do {
      context = try await fetchContext()
    } catch {
      return []
    }

    async let finishedTask: [HomeTeamGame] = (try? await fetchEvents(
      seasonID: context.seasonID,
      isFinished: true,
      selectedDriver: team,
      categoryID: context.categoryID
    )) ?? []
    async let upcomingTask: [HomeTeamGame] = (try? await fetchEvents(
      seasonID: context.seasonID,
      isFinished: false,
      selectedDriver: team,
      categoryID: context.categoryID
    )) ?? []

    let merged = await finishedTask + upcomingTask
    var byID: [String: HomeTeamGame] = [:]
    for game in merged {
      byID[game.id] = game
    }

    return byID.values.sorted { $0.startTimeUTC < $1.startTimeUTC }
  }

  static func fetchSummary(for team: TeamDefinition) async throws -> HomeTeamTeamSummary? {
    guard team.sport == .motogp else {
      return nil
    }

    let context = try await fetchContext()
    guard
      let standingsURL = Self.url(
        path: "standings",
        queryItems: [
          URLQueryItem(name: "seasonUuid", value: context.seasonID),
          URLQueryItem(name: "categoryUuid", value: context.categoryID),
        ]
      )
    else {
      return nil
    }

    let payload = try await fetchJSONObject(from: standingsURL)
    let classifications = payload["classification"] as? [[String: Any]] ?? []

    guard let favorite = classifications.first(where: { classification in
      matchesSelectedDriver(classification: classification, selectedDriver: team)
    }) else {
      return nil
    }

    let place = Self.string(from: favorite["position"]) ?? "-"
    let points = Self.string(from: favorite["points"]) ?? "-"
    var wins = Self.string(from: favorite["wins"]) ?? "-"
    var podiums = Self.string(from: favorite["podiums"]) ?? "-"

    if wins == "-" || podiums == "-" {
      if let games = try? await fetchGames(for: team) {
        let finals = games.filter { $0.status == .final }
        if wins == "-" {
          wins = "\(finals.filter { $0.awayScore == 1 }.count)"
        }
        if podiums == "-" {
          podiums = "\(finals.filter { ($0.awayScore ?? Int.max) <= 3 }.count)"
        }
      }
    }

    return HomeTeamTeamSummary(
      record: points,
      place: place,
      last10: wins,
      streak: podiums,
      style: .racingDriver
    )
  }

  private static func fetchEvents(
    seasonID: String,
    isFinished: Bool,
    selectedDriver: TeamDefinition,
    categoryID: String
  ) async throws -> [HomeTeamGame] {
    guard
      let url = Self.url(
        path: "events",
        queryItems: [
          URLQueryItem(name: "seasonUuid", value: seasonID),
          URLQueryItem(name: "categoryUuid", value: categoryID),
          URLQueryItem(name: "isFinished", value: isFinished ? "true" : "false"),
        ]
      )
    else {
      return []
    }

    let rows = try await fetchJSONArray(from: url)
    let limit = isFinished ? 8 : 8
    let sortedRows = rows.sorted { lhs, rhs in
      (eventDate(from: lhs) ?? .distantPast) < (eventDate(from: rhs) ?? .distantPast)
    }
    let selectedRows: [[String: Any]]
    if isFinished {
      selectedRows = Array(sortedRows.suffix(limit))
    } else {
      selectedRows = Array(sortedRows.prefix(limit))
    }

    return await withTaskGroup(of: [HomeTeamGame].self) { group in
      for row in selectedRows {
        group.addTask {
          await makeGames(
            from: row,
            selectedDriver: selectedDriver,
            categoryID: categoryID,
            isFinished: isFinished
          )
        }
      }

      var games: [HomeTeamGame] = []
      for await groupGames in group {
        games.append(contentsOf: groupGames)
      }
      return games
    }
  }

  private struct MotoGPScoringSession {
    let id: String
    let kind: Kind
    let startDate: Date

    enum Kind: Equatable {
      case sprint
      case race
    }
  }

  private static func makeGames(
    from row: [String: Any],
    selectedDriver: TeamDefinition,
    categoryID: String,
    isFinished: Bool
  ) async -> [HomeTeamGame] {
    guard
      let eventID = string(from: row["id"]),
      let eventStartDate = eventDate(from: row)
    else {
      return []
    }

    let eventName = string(from: row["sponsored_name"])
      ?? string(from: row["name"])
      ?? string(from: row["short_name"])
      ?? "MotoGP"
    let normalizedEventName = eventName.lowercased()
    if normalizedEventName.contains("test") {
      return []
    }

    let venue = ((row["circuit"] as? [String: Any]).flatMap { string(from: $0["name"]) })
      ?? eventName
    let favoriteLogoURL = RacingTeamLogoCatalog.logoURL(for: selectedDriver.name, sport: .motogp)

    var sessions = (try? await scoringSessions(eventID: eventID, categoryID: categoryID)) ?? []
    if isFinished {
      sessions = sessions.filter { $0.kind == .race }
    }

    if sessions.isEmpty {
      let looksLikeGrandPrix = normalizedEventName.contains("grand prix") || normalizedEventName.hasSuffix(" gp")
      guard looksLikeGrandPrix else {
        return []
      }

      return [
        makePulseLiveGame(
          id: "\(eventID)-\(selectedDriver.id)",
          startDate: eventStartDate,
          eventName: eventName,
          venue: venue,
          status: isFinished ? .final : .scheduled,
          favoriteLogoURL: favoriteLogoURL,
          selectedDriver: selectedDriver,
          classification: []
        ),
      ]
    }

    let now = Date()
    let relevantSessions: [MotoGPScoringSession] = {
      if isFinished {
        let completed = sessions.filter { $0.startDate <= now }
        return completed.isEmpty ? sessions : completed
      }

      let upcoming = sessions.filter { $0.startDate >= now }
      return upcoming.isEmpty ? sessions : upcoming
    }()

    return await withTaskGroup(of: HomeTeamGame.self) { group in
      for session in relevantSessions {
        group.addTask {
          let status: GameStatus = isFinished ? .final : .scheduled
          let sessionLabel = session.kind == .sprint ? "\(eventName) Sprint" : eventName

          let classification: [RacingResultLine]
          if status == .final {
            classification = (try? await fetchSessionClassification(
              sessionID: session.id,
              selectedDriver: selectedDriver
            )) ?? []
          } else {
            classification = []
          }

          return makePulseLiveGame(
            id: "\(eventID)-\(session.id)-\(selectedDriver.id)",
            startDate: session.startDate,
            eventName: sessionLabel,
            venue: venue,
            status: status,
            favoriteLogoURL: favoriteLogoURL,
            selectedDriver: selectedDriver,
            classification: classification
          )
        }
      }

      var games: [HomeTeamGame] = []
      for await game in group {
        games.append(game)
      }
      return games.sorted { $0.startTimeUTC < $1.startTimeUTC }
    }
  }

  private static func makePulseLiveGame(
    id: String,
    startDate: Date,
    eventName: String,
    venue: String,
    status: GameStatus,
    favoriteLogoURL: String?,
    selectedDriver: TeamDefinition,
    classification: [RacingResultLine]
  ) -> HomeTeamGame {
    let favoritePlace = classification.first(where: { $0.isFavorite })?.place
    let competitorCount = classification.isEmpty ? nil : classification.count
    var lines = Array(classification.prefix(3))
    if
      let favorite = classification.first(where: { $0.isFavorite }),
      favorite.place > 3
    {
      lines.append(favorite)
    }
    let racingResults = lines.isEmpty ? nil : lines
    let showFavoriteIdentity = status != .scheduled || racingResults != nil

    return HomeTeamGame(
      id: id,
      startTimeUTC: startDate,
      venue: venue,
      status: status,
      statusDetail: status == .final ? "Final" : "",
      homeTeam: eventName,
      awayTeam: selectedDriver.displayName,
      homeAbbrev: status == .scheduled ? "" : eventName.racingEventAbbreviation,
      awayAbbrev: showFavoriteIdentity ? selectedDriver.abbreviation : "",
      homeLogoURL: nil,
      awayLogoURL: showFavoriteIdentity ? favoriteLogoURL : nil,
      homeScore: status == .scheduled ? nil : competitorCount,
      awayScore: status == .scheduled ? nil : favoritePlace,
      homeRecord: nil,
      awayRecord: favoritePlace.map { "P\($0)" },
      streamingServices: [],
      sport: .motogp,
      racingResults: racingResults
    )
  }

  private static func scoringSessions(
    eventID: String,
    categoryID: String
  ) async throws -> [MotoGPScoringSession] {
    guard
      let sessionsURL = Self.url(
        path: "sessions",
        queryItems: [
          URLQueryItem(name: "eventUuid", value: eventID),
          URLQueryItem(name: "categoryUuid", value: categoryID),
        ]
      )
    else {
      return []
    }

    let sessions = try await fetchJSONArray(from: sessionsURL)
    var parsed: [MotoGPScoringSession] = []
    for session in sessions {
      guard
        let id = string(from: session["id"]),
        let startDate = eventDate(from: session)
      else {
        continue
      }

      let rawType = (
        string(from: session["type"])
          ?? string(from: session["code"])
          ?? string(from: session["name"])
          ?? string(from: session["short_name"])
          ?? ""
      ).lowercased()

      let kind: MotoGPScoringSession.Kind?
      if rawType.contains("spr") || rawType.contains("sprint") {
        kind = .sprint
      } else if rawType.contains("rac") || rawType.contains("race") || rawType.contains("grand prix") {
        kind = .race
      } else {
        kind = nil
      }

      guard let kind else {
        continue
      }

      parsed.append(.init(id: id, kind: kind, startDate: startDate))
    }

    var seen = Set<String>()
    return parsed
      .sorted { $0.startDate < $1.startDate }
      .filter { session in
        seen.insert(session.id).inserted
      }
  }

  private static func fetchSessionClassification(
    sessionID: String,
    selectedDriver: TeamDefinition
  ) async throws -> [RacingResultLine] {
    guard let classificationURL = URL(string: "\(baseURL)/session/\(sessionID)/classification?test=false") else {
      return []
    }

    let payload = try await fetchJSONObject(from: classificationURL)
    let rows = payload["classification"] as? [[String: Any]] ?? []

    var lines: [RacingResultLine] = []
    for row in rows {
      guard let place = int(from: row["position"]), place > 0 else {
        continue
      }

      let rider = row["rider"] as? [String: Any]
      let driverName = string(from: rider?["short_name"])
        ?? string(from: rider?["full_name"])
        ?? string(from: rider?["name"])
        ?? "Driver"
      let constructor = row["constructor"] as? [String: Any]
      let team = row["team"] as? [String: Any]
      let teamName = string(from: constructor?["name"])
        ?? string(from: team?["name"])
        ?? "Team"
      let favoriteCandidate = string(from: rider?["full_name"]) ?? driverName
      let isFavorite = favoriteCandidate.matchesPersonName(selectedDriver.city)
        || favoriteCandidate.matchesPersonName(selectedDriver.displayName)

      lines.append(
        RacingResultLine(
          place: place,
          driver: driverName,
          team: teamName,
          teamAbbrev: RacingTeamLogoCatalog.teamAbbreviation(for: teamName, sport: .motogp),
          teamLogoURL: RacingTeamLogoCatalog.logoURL(for: teamName, sport: .motogp),
          isFavorite: isFavorite
        )
      )
    }

    return lines.sorted { $0.place < $1.place }
  }

  private static func matchesSelectedDriver(
    classification: [String: Any],
    selectedDriver: TeamDefinition
  ) -> Bool {
    let rider = (classification["rider"] as? [String: Any])
      ?? (classification["athlete"] as? [String: Any])
    let names = [
      string(from: rider?["full_name"]),
      string(from: rider?["fullName"]),
      string(from: rider?["short_name"]),
      string(from: rider?["shortName"]),
      string(from: rider?["name"]),
    ].compactMap { $0 }

    return names.contains { candidate in
      candidate.matchesPersonName(selectedDriver.city)
        || candidate.matchesPersonName(selectedDriver.displayName)
    }
  }

  private static func fetchContext() async throws -> (seasonID: String, categoryID: String) {
    guard let seasonsURL = URL(string: "\(baseURL)/seasons") else {
      throw ScheduleClientError.invalidTeamURL
    }

    let seasons = try await fetchJSONArray(from: seasonsURL)
    let currentYear = Calendar.current.component(.year, from: Date())
    let orderedSeasons = seasons.sorted { lhs, rhs in
      (int(from: lhs["year"]) ?? 0) > (int(from: rhs["year"]) ?? 0)
    }
    guard
      let selectedSeason = orderedSeasons.first(where: {
        bool(from: $0["current"]) == true || int(from: $0["year"]) == currentYear
      }) ?? orderedSeasons.first,
      let seasonID = string(from: selectedSeason["id"])
    else {
      throw ScheduleClientError.invalidResponse
    }

    guard
      let categoriesURL = Self.url(
        path: "categories",
        queryItems: [URLQueryItem(name: "seasonUuid", value: seasonID)]
      )
    else {
      throw ScheduleClientError.invalidTeamURL
    }

    let categories = try await fetchJSONArray(from: categoriesURL)
    guard
      let motoCategory = categories.first(where: { category in
        (string(from: category["name"]) ?? "").lowercased().contains("motogp")
      }) ?? categories.first,
      let categoryID = string(from: motoCategory["id"])
    else {
      throw ScheduleClientError.invalidResponse
    }

    return (seasonID: seasonID, categoryID: categoryID)
  }

  private static func fetchJSONArray(from url: URL) async throws -> [[String: Any]] {
    let object = try await fetchJSON(from: url)
    if let array = object as? [[String: Any]] {
      return array
    }
    if
      let dict = object as? [String: Any],
      let array = dict["items"] as? [[String: Any]]
    {
      return array
    }
    return []
  }

  private static func fetchJSONObject(from url: URL) async throws -> [String: Any] {
    let object = try await fetchJSON(from: url)
    return object as? [String: Any] ?? [:]
  }

  private static func fetchJSON(from url: URL) async throws -> Any {
    let (data, response) = try await URLSession.shared.data(from: url)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw ScheduleClientError.badStatusCode(http.statusCode)
    }
    return try JSONSerialization.jsonObject(with: data, options: [])
  }

  private static func url(path: String, queryItems: [URLQueryItem]) -> URL? {
    guard var components = URLComponents(string: "\(baseURL)/\(path)") else {
      return nil
    }
    components.queryItems = queryItems
    return components.url
  }

  private static func string(from any: Any?) -> String? {
    if let value = any as? String {
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      return trimmed.isEmpty ? nil : trimmed
    }
    if let value = any as? NSNumber {
      return value.stringValue
    }
    return nil
  }

  private static func int(from any: Any?) -> Int? {
    if let value = any as? Int {
      return value
    }
    if let value = any as? NSNumber {
      return value.intValue
    }
    if let value = any as? String {
      return Int(value)
    }
    return nil
  }

  private static func bool(from any: Any?) -> Bool? {
    if let value = any as? Bool {
      return value
    }
    if let value = any as? NSNumber {
      return value.boolValue
    }
    if let value = any as? String {
      return ["true", "1", "yes"].contains(value.lowercased())
    }
    return nil
  }

  private static func date(from any: Any?) -> Date? {
    guard let raw = string(from: any) else {
      return nil
    }
    return EspnDateParser.parse(raw)
  }

  private static func eventDate(from row: [String: Any]) -> Date? {
    date(from: row["date_start"])
      ?? date(from: row["dateStart"])
      ?? date(from: row["start_date"])
      ?? date(from: row["startDate"])
      ?? date(from: row["date"])
  }
}

private struct EspnRacingScoreboardPayload: Decodable {
  let events: [EspnRacingEvent]

  enum CodingKeys: String, CodingKey {
    case events
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    events = try container.decodeIfPresent([EspnRacingEvent].self, forKey: .events) ?? []
  }
}

private struct EspnRacingEvent: Decodable {
  let id: String
  let name: String?
  let shortName: String?
  let date: Date?
  let competitions: [EspnRacingCompetition]

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case shortName
    case date
    case competitions
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let stringID = try container.decodeIfPresent(String.self, forKey: .id), !stringID.isEmpty {
      id = stringID
    } else if let intID = try container.decodeIfPresent(Int.self, forKey: .id) {
      id = String(intID)
    } else {
      id = UUID().uuidString
    }

    name = try container.decodeIfPresent(String.self, forKey: .name)
    shortName = try container.decodeIfPresent(String.self, forKey: .shortName)
    date = try container.decodeIfPresent(Date.self, forKey: .date)
    competitions = try container.decodeIfPresent([EspnRacingCompetition].self, forKey: .competitions) ?? []
  }

  var referenceDate: Date {
    competitions.first?.date ?? date ?? .distantPast
  }
}

private struct EspnRacingCompetition: Decodable {
  let id: String?
  let date: Date?
  let venue: EspnVenue?
  let status: EspnStatus
  let type: EspnCompetitionType?
  let competitors: [EspnCompetitor]
  let broadcasts: [EspnRacingBroadcast]

  enum CodingKeys: String, CodingKey {
    case id
    case date
    case venue
    case status
    case type
    case competitors
    case broadcasts
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    if let stringID = try container.decodeIfPresent(String.self, forKey: .id), !stringID.isEmpty {
      id = stringID
    } else if let intID = try container.decodeIfPresent(Int.self, forKey: .id) {
      id = String(intID)
    } else {
      id = nil
    }
    date = try container.decodeIfPresent(Date.self, forKey: .date)
    venue = try container.decodeIfPresent(EspnVenue.self, forKey: .venue)
    status = try container.decodeIfPresent(EspnStatus.self, forKey: .status) ?? EspnStatus(type: EspnStatusType())
    type = try container.decodeIfPresent(EspnCompetitionType.self, forKey: .type)
    competitors = try container.decodeIfPresent([EspnCompetitor].self, forKey: .competitors) ?? []
    broadcasts = try container.decodeIfPresent([EspnRacingBroadcast].self, forKey: .broadcasts) ?? []
  }
}

private struct EspnCompetitionType: Decodable {
  let abbreviation: String?
  let text: String?
}

private struct EspnRacingBroadcast: Decodable {
  let names: [String]
  let media: EspnMedia?

  enum CodingKeys: String, CodingKey {
    case names
    case media
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    media = try container.decodeIfPresent(EspnMedia.self, forKey: .media)

    if let values = try container.decodeIfPresent([String].self, forKey: .names) {
      names = values
    } else if let value = try container.decodeIfPresent(String.self, forKey: .names) {
      names = [value]
    } else {
      names = []
    }
  }

  var labels: [String] {
    var values = names
    if let shortName = media?.shortName, !shortName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      values.append(shortName)
    }
    return values
  }
}

private struct EspnRacingStandingsPayload: Decodable {
  let children: [EspnRacingStandingsChild]
}

private struct EspnRacingStandingsChild: Decodable {
  let name: String
  let standings: EspnRacingStandingsEntries
}

private struct EspnRacingStandingsEntries: Decodable {
  let entries: [EspnRacingStandingEntry]
}

private struct EspnRacingStandingEntry: Decodable {
  let athlete: EspnAthlete?
  let stats: [EspnRacingStandingStat]

  func matches(driver: TeamDefinition) -> Bool {
    if let id = athlete?.id, id == driver.id {
      return true
    }

    let candidateNames = [athlete?.displayName, athlete?.shortName].compactMap { $0 }
    let targetNames = [driver.city, driver.displayName]
    for candidate in candidateNames {
      if targetNames.contains(where: { candidate.matchesPersonName($0) }) {
        return true
      }
    }

    return false
  }
}

private struct EspnRacingStandingStat: Decodable {
  let name: String
  let displayValue: String?
}

private enum EspnDateParser {
  private static let withSeconds: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()

  private static let fallbackFormatters: [DateFormatter] = [
    makeFormatter("yyyy-MM-dd'T'HH:mm'Z'"),
    makeFormatter("yyyy-MM-dd'T'HH:mm:ss'Z'"),
    makeFormatter("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"),
    makeFormatter("yyyy-MM-dd'T'HH:mmXXX"),
    makeFormatter("yyyy-MM-dd'T'HH:mm:ssXXX"),
    makeFormatter("yyyy-MM-dd'T'HH:mm:ss.SSSXXX"),
    makeFormatter("yyyy-MM-dd"),
  ]

  static func parse(_ raw: String) -> Date? {
    if let withSeconds = withSeconds.date(from: raw) {
      return withSeconds
    }

    for formatter in fallbackFormatters {
      if let parsed = formatter.date(from: raw) {
        return parsed
      }
    }

    return nil
  }

  private static func makeFormatter(_ format: String) -> DateFormatter {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = format
    return formatter
  }
}

private enum NHLStandingsClient {
  private static let endpoint = URL(string: "https://api-web.nhle.com/v1/standings/now")!

  static func fetchRecordMap() async throws -> [String: String] {
    let payload = try await fetchPayload()
    var map: [String: String] = [:]

    for standing in payload.standings {
      let abbrev = standing.teamAbbrev.defaultValue.uppercased()
      guard !abbrev.isEmpty else {
        continue
      }

      map[abbrev] = "\(standing.wins)-\(standing.losses)-\(standing.otLosses)"
    }

    return map
  }

  static func fetchTeamSummary(teamAbbreviation: String) async throws -> HomeTeamTeamSummary? {
    let payload = try await fetchPayload()
    guard let team = payload.standings.first(where: { $0.teamAbbrev.defaultValue.uppercased() == teamAbbreviation.uppercased() }) else {
      return nil
    }

    let place = "\(ordinal(team.divisionSequence)) in \(team.divisionName) Division"
    let last10 = "\(team.l10Wins)-\(team.l10Losses)-\(team.l10OtLosses)"
    let streak = "\(team.streakCode.uppercased())\(team.streakCount)"

    return HomeTeamTeamSummary(
      record: "\(team.wins)-\(team.losses)-\(team.otLosses)",
      place: place,
      last10: last10,
      streak: streak
    )
  }

  private static func fetchPayload() async throws -> NHLStandingsPayload {
    let (data, response) = try await URLSession.shared.data(from: endpoint)
    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw ScheduleClientError.badStatusCode(http.statusCode)
    }

    return try JSONDecoder().decode(NHLStandingsPayload.self, from: data)
  }

  private static func ordinal(_ value: Int) -> String {
    let tens = value % 100
    if tens == 11 || tens == 12 || tens == 13 {
      return "\(value)th"
    }

    switch value % 10 {
    case 1: return "\(value)st"
    case 2: return "\(value)nd"
    case 3: return "\(value)rd"
    default: return "\(value)th"
    }
  }
}

private struct NHLStandingsPayload: Decodable {
  let standings: [NHLStanding]
}

private struct NHLStanding: Decodable {
  let teamAbbrev: NHLTeamAbbrev
  let wins: Int
  let losses: Int
  let otLosses: Int
  let divisionName: String
  let divisionSequence: Int
  let l10Wins: Int
  let l10Losses: Int
  let l10OtLosses: Int
  let streakCode: String
  let streakCount: Int
}

private struct NHLTeamAbbrev: Decodable {
  let defaultValue: String

  enum CodingKeys: String, CodingKey {
    case defaultValue = "default"
  }
}

private extension HomeTeamGame {
  func fillingMissingRecords(from recordMap: [String: String]) -> HomeTeamGame {
    let homeKey = Self.standingsLookupKey(from: homeAbbrev)
    let awayKey = Self.standingsLookupKey(from: awayAbbrev)

    return HomeTeamGame(
      id: id,
      startTimeUTC: startTimeUTC,
      venue: venue,
      status: status,
      statusDetail: statusDetail,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeAbbrev: homeAbbrev,
      awayAbbrev: awayAbbrev,
      homeLogoURL: homeLogoURL,
      awayLogoURL: awayLogoURL,
      homeScore: homeScore,
      awayScore: awayScore,
      homeRecord: homeRecord ?? recordMap[homeAbbrev.uppercased()] ?? recordMap[homeKey],
      awayRecord: awayRecord ?? recordMap[awayAbbrev.uppercased()] ?? recordMap[awayKey],
      streamingServices: streamingServices,
      sport: sport,
      racingResults: racingResults
    )
  }

  private static func standingsLookupKey(from abbrev: String) -> String {
    let upper = abbrev.uppercased()
    switch upper {
    case "NJ":
      return "NJD"
    case "LA":
      return "LAK"
    case "SJ":
      return "SJS"
    case "TB":
      return "TBL"
    default:
      return upper
    }
  }
}
