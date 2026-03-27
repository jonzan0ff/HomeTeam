import Foundation

// F1 scoreboard: competitors array is empty; race info is on the event itself.
// Circuit is on event.circuit, not competition.

struct ESPNRacingParser {

  static func parse(_ data: Data, sport: SupportedSport) throws -> [HomeTeamGame] {
    let root = try JSONDecoder().decode(ESPNScoreboardRoot.self, from: data)
    return root.events.compactMap { raceGame(from: $0, sport: sport) }
  }

  // ESPN omits seconds: "2026-03-27T02:30Z" — same format as team schedule API
  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd'T'HH:mmX"
    return f
  }()

  // type.id == 3 is the race; fall back to the last competition, then event date
  private static func raceCompetition(from event: ESPNScoreboardEvent) -> ESPNScoreboardCompetition? {
    event.competitions.first(where: { $0.type?.id == 3 }) ?? event.competitions.last
  }

  private static func raceGame(from event: ESPNScoreboardEvent, sport: SupportedSport) -> HomeTeamGame? {
    let raceComp = raceCompetition(from: event)
    let dateStr = raceComp?.date ?? event.date
    guard let date = dateFormatter.date(from: dateStr) else { return nil }
    let status = mapStatus(event.status)
    let venue = event.circuit?.fullName ?? raceComp?.venue?.fullName

    let broadcasts = raceComp?.broadcastNames ?? []

    // Populate top-3 finishers when the race is complete
    let racingResults: [RacingResultLine]? = {
      guard status == .final, let comp = raceComp else { return nil }
      let finishers = (comp.competitors ?? [])
        .compactMap { c -> (Int, ESPNRacingCompetitor)? in
          guard let pos = c.order, pos > 0 else { return nil }
          return (pos, c)
        }
        .sorted { $0.0 < $1.0 }
        .prefix(3)
      let lines = finishers.map { (pos, c) in
        RacingResultLine(
          position: pos,
          driverName: c.athlete?.shortName ?? c.athlete?.displayName ?? "Unknown",
          teamName: c.team?.displayName,
          timeOrGap: nil
        )
      }
      return lines.isEmpty ? nil : lines
    }()

    return HomeTeamGame(
      id: event.id,
      sport: sport,
      homeTeamID: "", awayTeamID: "",
      homeTeamName: event.name,  // stored verbatim; compactRaceName() formats at display time
      awayTeamName: "",
      homeTeamAbbrev: "", awayTeamAbbrev: "",
      homeScore: nil, awayScore: nil,
      homeRecord: nil, awayRecord: nil,
      scheduledAt: date,
      status: status,
      statusDetail: event.status.type?.detail,
      venueName: venue,
      broadcastNetworks: broadcasts,
      isPlayoff: false,
      seriesInfo: nil,
      racingResults: racingResults
    )
  }

  private static func mapStatus(_ s: ESPNScoreboardStatus) -> GameStatus {
    switch s.type?.state {
    case "pre":  return .scheduled
    case "in":   return .live
    case "post": return s.type?.completed == true ? .final : .postponed
    default:     return .scheduled
    }
  }
}

private struct ESPNScoreboardRoot: Decodable {
  let events: [ESPNScoreboardEvent]
}

private struct ESPNScoreboardEvent: Decodable {
  let id: String
  let name: String
  let date: String
  let status: ESPNScoreboardStatus
  let competitions: [ESPNScoreboardCompetition]
  let circuit: ESPNCircuit?
}

private struct ESPNCircuit: Decodable {
  let fullName: String?
  let address: ESPNCircuitAddress?
}

private struct ESPNCircuitAddress: Decodable {
  let city: String?
  let country: String?
}

private struct ESPNScoreboardStatus: Decodable {
  let type: ESPNScoreboardStatusType?
}

private struct ESPNScoreboardStatusType: Decodable {
  let state: String
  let completed: Bool
  let detail: String
}

private struct ESPNScoreboardCompetition: Decodable {
  let date: String?
  let type: ESPNCompetitionType?
  let venue: ESPNScoreboardVenue?
  // ESPN racing broadcasts: [{"market":"national","names":["Apple TV"]}]
  let broadcasts: [ESPNScoreboardBroadcast]?
  let competitors: [ESPNRacingCompetitor]?

  var broadcastNames: [String] {
    broadcasts?.flatMap { $0.names ?? [] } ?? []
  }
}

private struct ESPNRacingCompetitor: Decodable {
  let order: Int?
  let athlete: ESPNRacingAthlete?
  let team: ESPNRacingTeamRef?
}

private struct ESPNRacingAthlete: Decodable {
  let displayName: String?
  let shortName: String?
}

private struct ESPNRacingTeamRef: Decodable {
  let displayName: String?
}

private struct ESPNCompetitionType: Decodable {
  let id: Int?

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    // ESPN sends type.id as either Int or String
    if let intVal = try? c.decode(Int.self, forKey: .id) {
      id = intVal
    } else if let strVal = try? c.decode(String.self, forKey: .id) {
      id = Int(strVal)
    } else {
      id = nil
    }
  }

  enum CodingKeys: String, CodingKey { case id }
}

private struct ESPNScoreboardVenue: Decodable {
  let fullName: String?
}

private struct ESPNScoreboardBroadcast: Decodable {
  let names: [String]?
}
