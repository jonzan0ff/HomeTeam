import Foundation

enum GameStatus: String, Codable {
  case scheduled
  case live
  case final
}

struct CapsGame: Codable, Identifiable, Equatable {
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
}

struct CapsTeamSummary: Codable, Equatable {
  let record: String
  let place: String
  let last10: String
  let streak: String

  var inlineDisplay: String {
    "\(record)  |  \(place)  |  L10 \(last10)  |  \(streak)"
  }
}

struct ScheduleSnapshot: Codable {
  let games: [CapsGame]
  let lastUpdated: Date
  let errorMessage: String?
  let teamSummary: CapsTeamSummary?

  var hasLiveGame: Bool {
    games.contains { $0.status == .live }
  }
}
