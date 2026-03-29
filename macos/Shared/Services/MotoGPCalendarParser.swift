import Foundation

// PulseLive MotoGP API:
// 1. GET /motogp/v1/results/seasons → find current season ID
// 2. GET /motogp/v1/results/events?seasonUuid={id}&isFinished=false → events
//
// Only shows upcoming events (isFinished=false).
// No session-type filter available at this endpoint level.
// No broadcast data in API — US rights are Fox/FS1/FS2; hardcoded below.

struct MotoGPCalendarParser {

  static func parse(_ data: Data) throws -> [HomeTeamGame] {
    let events = try JSONDecoder().decode([MotoGPEvent].self, from: data)
    return events.filter { $0.test != true }.compactMap { game(from: $0) }
  }

  /// Looks up the event short_name for a given event UUID from raw events data.
  /// Used to match live timing data (which has short_name) to our game objects (which have UUID).
  static func shortName(from eventID: String, in data: Data) -> String? {
    guard let events = try? JSONDecoder().decode([MotoGPEvent].self, from: data) else { return nil }
    return events.first(where: { $0.id == eventID })?.shortName
  }

  /// Maps event UUID → circuit TimeZone for session timestamp correction.
  /// The Pulselive API stores session times in circuit-local time but labels
  /// the offset as +00:00, so callers must re-interpret using the circuit TZ.
  static func circuitTimezones(from data: Data) -> [String: TimeZone] {
    guard let events = try? JSONDecoder().decode([MotoGPEvent].self, from: data) else { return [:] }
    var result: [String: TimeZone] = [:]
    for event in events {
      guard let legacyID = event.circuit?.legacyID,
            let tzID = Self.circuitTimezoneID(legacyID: legacyID),
            let tz = TimeZone(identifier: tzID) else { continue }
      result[event.id] = tz
    }
    return result
  }

  // Pulselive circuit legacy_id → IANA timezone identifier.
  // All 22 circuits on the 2026 calendar.
  private static func circuitTimezoneID(legacyID: Int) -> String? {
    switch legacyID {
    case 106: return "Asia/Bangkok"          // Buriram, Thailand
    case  39: return "America/Sao_Paulo"     // Goiania, Brazil
    case 101: return "America/Chicago"       // Austin, USA (COTA)
    case   4: return "Europe/Madrid"         // Jerez, Spain
    case   8: return "Europe/Paris"          // Le Mans, France
    case  13: return "Europe/Madrid"         // Barcelona, Spain
    case   6: return "Europe/Rome"           // Mugello, Italy
    case 115: return "Europe/Budapest"       // Balatonfokajár, Hungary
    case  11: return "Europe/Prague"         // Brno, Czech Republic
    case   7: return "Europe/Amsterdam"      // Assen, Netherlands
    case  51: return "Europe/Berlin"         // Sachsenring, Germany
    case  42: return "Europe/London"         // Silverstone, UK
    case 100: return "Europe/Madrid"         // Alcañiz, Spain
    case  38: return "Europe/Rome"           // Misano, Italy
    case  24: return "Europe/Vienna"         // Spielberg, Austria
    case  76: return "Asia/Tokyo"            // Motegi, Japan
    case 111: return "Asia/Makassar"         // Lombok, Indonesia
    case  32: return "Australia/Melbourne"   // Phillip Island, Australia
    case  75: return "Asia/Kuala_Lumpur"     // Sepang, Malaysia
    case  93: return "Asia/Qatar"            // Doha, Qatar
    case 109: return "Europe/Lisbon"         // Portimao, Portugal
    case  77: return "Europe/Madrid"         // Cheste, Spain
    default:  return nil
    }
  }

  // MotoGP API returns date-only strings: "2026-03-27". Parse in local timezone so
  // the calendar day is correct. Exact race time is patched later from session data.
  private static let dateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = TimeZone.current
    return f
  }()

  private static func normalizedName(_ raw: String?) -> String {
    guard let raw else { return "MotoGP Race" }
    let gp = raw.replacingOccurrences(of: "grand prix", with: "GP", options: [.caseInsensitive])
    // Title-case: lowercase then capitalize each word, then fix "Gp" back to "GP"
    return gp.lowercased().capitalized.replacingOccurrences(of: "Gp", with: "GP")
  }

  private static func game(from event: MotoGPEvent) -> HomeTeamGame? {
    // Use date_end (race day) if available, else fall back to date_start
    let dateString = event.dateEnd ?? event.dateStart
    guard let date = dateFormatter.date(from: dateString) else { return nil }

    let status: GameStatus
    switch event.status?.uppercased() {
    case "IN-PROGRESS": status = .live                  // race is actively running
    case "STARTED", "CURRENT": status = .scheduled      // race weekend underway, race not yet run
    case "FINISHED", "CLOSED", "COMPLETED", "ENDED": status = .final
    default:
      // If date is unambiguously in the past, treat as final regardless of unknown status string.
      status = date < Date() ? .final : .scheduled
    }

    let venueName = [event.circuit?.name, event.circuit?.place, event.circuit?.nation]
      .compactMap { $0 }.joined(separator: ", ")

    return HomeTeamGame(
      id: event.id,
      sport: .motoGP,
      homeTeamID: "", awayTeamID: "",
      homeTeamName: normalizedName(event.name ?? event.sponsoredName),
      awayTeamName: "",
      homeTeamAbbrev: "", awayTeamAbbrev: "",
      homeScore: nil, awayScore: nil,
      homeRecord: nil, awayRecord: nil,
      scheduledAt: date,
      status: status,
      statusDetail: nil,
      venueName: venueName.isEmpty ? nil : venueName,
      broadcastNetworks: ["FS1"],
      isPlayoff: false,
      seriesInfo: nil,
      racingResults: nil
    )
  }
}

struct MotoGPEvent: Decodable {
  let id: String
  let name: String?
  let sponsoredName: String?
  let shortName: String?
  let dateStart: String
  let dateEnd: String?
  let status: String?
  let circuit: MotoGPCircuit?
  let test: Bool?

  enum CodingKeys: String, CodingKey {
    case id, name, status, circuit, test
    case sponsoredName = "sponsored_name"
    case shortName = "short_name"
    case dateStart = "date_start"
    case dateEnd = "date_end"
  }
}

struct MotoGPCircuit: Decodable {
  let name: String?
  let place: String?
  let nation: String?
  let legacyID: Int?

  enum CodingKeys: String, CodingKey {
    case name, place, nation
    case legacyID = "legacy_id"
  }
}
