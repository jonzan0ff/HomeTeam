import Foundation

enum GameStatus: String, Codable {
  case scheduled
  case live
  case final
}

struct HomeTeamGame: Codable, Identifiable, Equatable {
  let id: String
  let startTimeUTC: Date
  let venue: String
  let status: GameStatus
  let statusDetail: String
  let homeTeam: String
  let awayTeam: String
  let homeAbbrev: String
  let awayAbbrev: String
  let homeLogoURL: String?
  let awayLogoURL: String?
  let homeScore: Int?
  let awayScore: Int?
  let homeRecord: String?
  let awayRecord: String?
  let streamingServices: [String]
  var sport: SupportedSport? = nil
  var racingResults: [RacingResultLine]? = nil
}

struct RacingResultLine: Codable, Equatable, Identifiable {
  let place: Int
  let driver: String
  let team: String
  let teamAbbrev: String
  let teamLogoURL: String?
  let isFavorite: Bool

  var id: String {
    "\(place)-\(driver)-\(team)"
  }

  var displayText: String {
    "\(driver) \(team)"
  }
}

struct HomeTeamTeamSummary: Codable, Equatable {
  enum Style: String, Codable {
    case standard
    case racingDriver
  }

  let record: String
  let place: String
  let last10: String
  let streak: String
  let style: Style

  var inlineDisplay: String {
    switch style {
    case .standard:
      return "\(record)  |  \(place)  |  L10 \(last10)  |  \(streak)"
    case .racingDriver:
      return "Place \(place)  |  Pts \(record)  |  Wins \(last10)  |  Podiums \(streak)"
    }
  }

  init(
    record: String,
    place: String,
    last10: String,
    streak: String,
    style: Style = .standard
  ) {
    self.record = record
    self.place = place
    self.last10 = last10
    self.streak = streak
    self.style = style
  }

  enum CodingKeys: String, CodingKey {
    case record
    case place
    case last10
    case streak
    case style
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    record = try container.decode(String.self, forKey: .record)
    place = try container.decode(String.self, forKey: .place)
    last10 = try container.decode(String.self, forKey: .last10)
    streak = try container.decode(String.self, forKey: .streak)
    style = try container.decodeIfPresent(Style.self, forKey: .style) ?? .standard
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(record, forKey: .record)
    try container.encode(place, forKey: .place)
    try container.encode(last10, forKey: .last10)
    try container.encode(streak, forKey: .streak)
    try container.encode(style, forKey: .style)
  }
}

struct ScheduleSnapshot: Codable {
  let games: [HomeTeamGame]
  let lastUpdated: Date
  let errorMessage: String?
  let teamSummary: HomeTeamTeamSummary?

  var hasLiveGame: Bool {
    games.contains { $0.status == .live }
  }

  /// When a refresh succeeds but returns no rows, keep prior cached games so we do not wipe good data (widget + main app share the store).
  func mergingNondestructively(withExisting existing: ScheduleSnapshot?) -> ScheduleSnapshot {
    guard errorMessage == nil, games.isEmpty, let existing, !existing.games.isEmpty else {
      return self
    }

    return ScheduleSnapshot(
      games: existing.games,
      lastUpdated: existing.lastUpdated,
      errorMessage: nil,
      teamSummary: teamSummary ?? existing.teamSummary
    )
  }
}
