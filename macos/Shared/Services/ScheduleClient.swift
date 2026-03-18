import Foundation

enum ScheduleClientError: Error {
  case badStatusCode(Int)
}

struct ScheduleClient {
  static let endpoint = URL(string: "https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/teams/23/schedule")!

  func fetchGames() async throws -> [CapsGame] {
    let (data, response) = try await URLSession.shared.data(from: Self.endpoint)

    if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
      throw ScheduleClientError.badStatusCode(http.statusCode)
    }

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
    let payload = try decoder.decode(EspnScheduleResponse.self, from: data)

    let mappedGames = payload.events
      .compactMap { $0.asCapsGame }
      .sorted { $0.startTimeUTC < $1.startTimeUTC }

    guard mappedGames.contains(where: { $0.homeRecord == nil || $0.awayRecord == nil }) else {
      return mappedGames
    }

    let standingsRecords = (try? await NHLStandingsClient.fetchRecordMap()) ?? [:]
    guard !standingsRecords.isEmpty else {
      return mappedGames
    }

    return mappedGames.map { game in
      game.fillingMissingRecords(from: standingsRecords)
    }
  }

  func fetchCapitalsSummary() async -> CapsTeamSummary? {
    try? await NHLStandingsClient.fetchCapitalsSummary()
  }
}

private struct EspnScheduleResponse: Decodable {
  let events: [EspnEvent]
}

private struct EspnEvent: Decodable {
  let id: String?
  let date: Date?
  let competitions: [EspnCompetition]

  var asCapsGame: CapsGame? {
    guard let competition = competitions.first else {
      return nil
    }

    guard
      let home = competition.competitors.first(where: { $0.homeAway == "home" }),
      let away = competition.competitors.first(where: { $0.homeAway == "away" }),
      let homeName = home.team.displayName,
      let awayName = away.team.displayName,
      let homeAbbrev = home.team.abbreviation,
      let awayAbbrev = away.team.abbreviation
    else {
      return nil
    }

    let broadcastLabels = competition.broadcasts.compactMap { $0.media?.shortName }
    let services = StreamingServiceMatcher.matchedServices(from: broadcastLabels)

    let status = competition.status.type.state.asGameStatus

    return CapsGame(
      id: id ?? "\(awayAbbrev)-\(homeAbbrev)-\(competition.date ?? date ?? .distantPast)",
      startTimeUTC: competition.date ?? date ?? .distantPast,
      venue: competition.venue?.fullName ?? "TBD",
      status: status,
      statusDetail: competition.status.type.shortDetail ?? competition.status.type.detail ?? "",
      homeTeam: homeName,
      awayTeam: awayName,
      homeAbbrev: homeAbbrev,
      awayAbbrev: awayAbbrev,
      homeLogoURL: home.team.bestLogoURL(forDarkBackground: true),
      awayLogoURL: away.team.bestLogoURL(forDarkBackground: true),
      homeScore: status == .scheduled ? nil : home.score?.value,
      awayScore: status == .scheduled ? nil : away.score?.value,
      homeRecord: home.displayRecord,
      awayRecord: away.displayRecord,
      streamingServices: services
    )
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
}

private struct EspnStatusType: Decodable {
  let state: String?
  let detail: String?
  let shortDetail: String?
}

private struct EspnCompetitor: Decodable {
  let homeAway: String
  let team: EspnTeam
  let score: EspnScore?
  let record: [EspnRecord]?
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
  var recordCore: String? {
    let firstSegment = self.split(separator: ",", maxSplits: 1).first?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let core = firstSegment, !core.isEmpty else {
      return nil
    }

    return core
  }
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

  static func fetchCapitalsSummary() async throws -> CapsTeamSummary? {
    let payload = try await fetchPayload()
    guard let capitals = payload.standings.first(where: { $0.teamAbbrev.defaultValue.uppercased() == "WSH" }) else {
      return nil
    }

    let place = "\(ordinal(capitals.divisionSequence)) in \(capitals.divisionName) Division"
    let last10 = "\(capitals.l10Wins)-\(capitals.l10Losses)-\(capitals.l10OtLosses)"
    let streak = "\(capitals.streakCode.uppercased())\(capitals.streakCount)"

    return CapsTeamSummary(
      record: "\(capitals.wins)-\(capitals.losses)-\(capitals.otLosses)",
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

private extension CapsGame {
  func fillingMissingRecords(from recordMap: [String: String]) -> CapsGame {
    let homeKey = Self.standingsLookupKey(from: homeAbbrev)
    let awayKey = Self.standingsLookupKey(from: awayAbbrev)

    return CapsGame(
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
      streamingServices: streamingServices
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
