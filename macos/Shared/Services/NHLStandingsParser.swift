import Foundation

// MARK: - NHL standings API → record strings for game backfill
// Returns a map of espnTeamID → "W-L-OT" record string.
// Used to backfill homeRecord/awayRecord on games that lack them.

enum NHLStandingsParser {

  static func parseRecordMap(_ data: Data) throws -> [String: String] {
    let root = try JSONDecoder().decode(NHLStandingsRoot.self, from: data)
    var map: [String: String] = [:]
    for entry in root.standings {
      let record = "\(entry.wins)-\(entry.losses)-\(entry.otLosses)"
      map[String(entry.team.id)] = record
    }
    return map
  }
}

// MARK: - JSON models

private struct NHLStandingsRoot: Decodable {
  let standings: [NHLStandingEntry]
}

private struct NHLStandingEntry: Decodable {
  let wins: Int
  let losses: Int
  let otLosses: Int
  let team: NHLTeamRef

  enum CodingKeys: String, CodingKey {
    case wins, losses, otLosses = "otLosses", team
  }
}

private struct NHLTeamRef: Decodable {
  let id: Int
  let commonName: NHLLocalizedString
}

private struct NHLLocalizedString: Decodable {
  let `default`: String
}
