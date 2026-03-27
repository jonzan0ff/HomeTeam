import Foundation

// MARK: - Game status

enum GameStatus: String, Codable, Equatable {
  case scheduled
  case live
  case final   = "final"
  case postponed
}

// MARK: - Core game model

struct HomeTeamGame: Codable, Identifiable, Equatable {
  let id: String
  let sport: SupportedSport
  let homeTeamID: String
  let awayTeamID: String
  let homeTeamName: String
  let awayTeamName: String
  let homeTeamAbbrev: String
  let awayTeamAbbrev: String
  let homeScore: Int?
  let awayScore: Int?
  let homeRecord: String?
  let awayRecord: String?
  let scheduledAt: Date
  let status: GameStatus
  let statusDetail: String?
  let venueName: String?
  let broadcastNetworks: [String]
  let isPlayoff: Bool
  let seriesInfo: String?
  let racingResults: [RacingResultLine]?
}

// MARK: - Racing result line

struct RacingResultLine: Codable, Equatable, Identifiable {
  let position: Int
  let driverName: String
  let teamName: String?
  let timeOrGap: String?

  var id: String { "\(position)-\(driverName)" }
}

// MARK: - Team summary (standings/record display)

struct HomeTeamTeamSummary: Codable, Equatable {
  enum Style: String, Codable {
    case standard
    case racingDriver
  }

  let compositeID: String   // e.g. "nhl:23" — used for widget/app lookup
  let record: String        // W-L-OT or championship points
  let place: String         // "3rd in Metropolitan" or "4th"
  let last10: String        // "6-3-1" or wins count for racing
  let streak: String        // "W3" or podiums count for racing
  let style: Style

  /// Formatted one-line summary for display in widget/app header.
  var inlineDisplay: String {
    switch style {
    case .standard:
      var parts = [record, HomeTeamTeamSummary.shortenPlace(place)]
      if last10 != "-" { parts.append("L10 \(last10)") }
      if streak != "-" { parts.append(streak) }
      return parts.joined(separator: "  |  ")
    case .racingDriver:
      return "Place \(place)  |  Pts \(record)  |  Wins \(last10)  |  Podiums \(streak)"
    }
  }

  private static func shortenPlace(_ place: String) -> String {
    var s = place
    let replacements: [(String, String)] = [
      ("National Football Conference", "NFC"),
      ("American Football Conference", "AFC"),
      ("National Basketball Association", "NBA"),
      ("Eastern Conference", "East. Conf."),
      ("Western Conference", "West. Conf."),
      ("Northern Conference", "North. Conf."),
      ("Southern Conference", "South. Conf."),
      ("National League", "NL"),
      ("American League", "AL"),
      ("Metropolitan Division", "Metro Div."),
      ("Atlantic Division", "Atlantic Div."),
      ("Pacific Division", "Pacific Div."),
      ("Central Division", "Central Div."),
      ("Northeast Division", "NE Div."),
      ("Southeast Division", "SE Div."),
      ("Northwest Division", "NW Div."),
      ("Southwest Division", "SW Div."),
    ]
    for (long, short) in replacements {
      if s.localizedCaseInsensitiveContains(long) {
        s = s.replacingOccurrences(of: long, with: short, options: .caseInsensitive)
        break
      }
    }
    return s
  }
}

// MARK: - Live score overlay

extension HomeTeamGame {
  /// Returns a copy with updated scores and statusDetail, keeping all other fields.
  func patching(homeScore: Int?, awayScore: Int?, statusDetail: String?) -> HomeTeamGame {
    HomeTeamGame(
      id: id, sport: sport,
      homeTeamID: homeTeamID, awayTeamID: awayTeamID,
      homeTeamName: homeTeamName, awayTeamName: awayTeamName,
      homeTeamAbbrev: homeTeamAbbrev, awayTeamAbbrev: awayTeamAbbrev,
      homeScore: homeScore, awayScore: awayScore,
      homeRecord: homeRecord, awayRecord: awayRecord,
      scheduledAt: scheduledAt, status: status,
      statusDetail: statusDetail ?? self.statusDetail,
      venueName: venueName, broadcastNetworks: broadcastNetworks,
      isPlayoff: isPlayoff, seriesInfo: seriesInfo,
      racingResults: racingResults
    )
  }
}

// MARK: - Schedule snapshot (written to App Group, read by widget)

struct ScheduleSnapshot: Codable {
  let games: [HomeTeamGame]
  let fetchedAt: Date
  let teamSummaries: [HomeTeamTeamSummary]

  init(games: [HomeTeamGame], fetchedAt: Date, teamSummaries: [HomeTeamTeamSummary] = []) {
    self.games = games
    self.fetchedAt = fetchedAt
    self.teamSummaries = teamSummaries
  }

  // Custom decode so old snapshots without teamSummaries field still load
  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    games = try c.decode([HomeTeamGame].self, forKey: .games)
    fetchedAt = try c.decode(Date.self, forKey: .fetchedAt)
    teamSummaries = (try? c.decodeIfPresent([HomeTeamTeamSummary].self, forKey: .teamSummaries)) ?? []
  }

  private enum CodingKeys: String, CodingKey {
    case games, fetchedAt, teamSummaries
  }

  /// Non-destructive merge: if the incoming snapshot has no games, keep cached games.
  /// Always take the latest teamSummaries if available.
  func mergingNondestructively(with incoming: ScheduleSnapshot) -> ScheduleSnapshot {
    let mergedSummaries = incoming.teamSummaries.isEmpty ? teamSummaries : incoming.teamSummaries
    guard incoming.games.isEmpty, !games.isEmpty else {
      return ScheduleSnapshot(games: incoming.games, fetchedAt: incoming.fetchedAt, teamSummaries: mergedSummaries)
    }
    return ScheduleSnapshot(games: games, fetchedAt: incoming.fetchedAt, teamSummaries: mergedSummaries)
  }
}
