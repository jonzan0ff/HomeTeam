import Foundation

struct ESPNScheduleParser {

  static func parse(_ data: Data, sport: SupportedSport, teamID: String) throws -> [HomeTeamGame] {
    let root = try JSONDecoder().decode(ESPNScheduleRoot.self, from: data)
    let games = root.events.compactMap { game(from: $0, sport: sport) }
    print("[ESPNScheduleParser] \(sport) teamID=\(teamID): \(root.events.count) events → \(games.count) games")
    return games
  }

  // ESPN omits seconds: "2026-03-25T19:00Z" — ISO8601DateFormatter default requires HH:MM:SS
  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd'T'HH:mmX"
    return f
  }()

  private static func game(from event: ESPNEvent, sport: SupportedSport) -> HomeTeamGame? {
    guard let competition = event.competitions.first else { return nil }
    guard let date = dateFormatter.date(from: event.date) else { return nil }

    let home = competition.competitors.first { $0.homeAway == "home" }
    let away = competition.competitors.first { $0.homeAway == "away" }

    let homeScore = home?.score?.displayValue.flatMap(Int.init)
    let awayScore = away?.score?.displayValue.flatMap(Int.init)
    // Record is an array; grab the ytd/total type first, fall back to first entry
    let homeRecord = home?.record?.first(where: { $0.type == "ytd" || $0.type == "total" })?.displayValue
                  ?? home?.record?.first?.displayValue
    let awayRecord = away?.record?.first(where: { $0.type == "ytd" || $0.type == "total" })?.displayValue
                  ?? away?.record?.first?.displayValue

    // Broadcasts: [{media: {shortName: "ESPN+"}, ...}]
    let broadcasts = competition.broadcasts?.compactMap { $0.media?.shortName } ?? []

    let status = mapStatus(competition.status)

    return HomeTeamGame(
      id: event.id,
      sport: sport,
      homeTeamID: home?.team.id ?? "",
      awayTeamID: away?.team.id ?? "",
      homeTeamName: home?.team.displayName ?? "",
      awayTeamName: away?.team.displayName ?? "",
      homeTeamAbbrev: home?.team.abbreviation ?? "",
      awayTeamAbbrev: away?.team.abbreviation ?? "",
      homeScore: homeScore,
      awayScore: awayScore,
      homeRecord: homeRecord,
      awayRecord: awayRecord,
      scheduledAt: date,
      status: status,
      statusDetail: competition.status.type.detail,
      venueName: competition.venue?.fullName,
      broadcastNetworks: broadcasts,
      isPlayoff: event.seasonType?.type == 3,
      seriesInfo: nil,
      racingResults: nil
    )
  }

  private static func mapStatus(_ s: ESPNStatus) -> GameStatus {
    switch s.type.state {
    case "pre":  return .scheduled
    case "in":   return .live
    case "post": return s.type.completed ? .final : .postponed
    default:     return .scheduled
    }
  }
}

private struct ESPNScheduleRoot: Decodable {
  let events: [ESPNEvent]
}

private struct ESPNEvent: Decodable {
  let id: String
  let date: String
  let competitions: [ESPNCompetition]
  let seasonType: ESPNSeasonType?
  enum CodingKeys: String, CodingKey { case id, date, competitions, seasonType }
}

private struct ESPNSeasonType: Decodable {
  let type: Int?
  let id: String?
}

private struct ESPNCompetition: Decodable {
  let competitors: [ESPNCompetitor]
  let status: ESPNStatus
  let broadcasts: [ESPNBroadcast]?
  let venue: ESPNVenue?
}

private struct ESPNCompetitor: Decodable {
  let homeAway: String
  let team: ESPNTeamRef
  let score: ESPNScore?
  let record: [ESPNRecord]?
}

private struct ESPNScore: Decodable {
  let displayValue: String?
}

private struct ESPNTeamRef: Decodable {
  let id: String
  let displayName: String
  let abbreviation: String
}

private struct ESPNRecord: Decodable {
  let displayValue: String
  let type: String?
}

private struct ESPNStatus: Decodable {
  let type: ESPNStatusType
}

private struct ESPNStatusType: Decodable {
  let state: String
  let completed: Bool
  let detail: String
}

private struct ESPNBroadcast: Decodable {
  let media: ESPNMedia?
}

private struct ESPNMedia: Decodable {
  let shortName: String?
}

private struct ESPNVenue: Decodable {
  let fullName: String?
}
