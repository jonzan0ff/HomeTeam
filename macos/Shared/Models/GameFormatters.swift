import Foundation

// MARK: - Game display formatting utilities (used by app + widget)

enum GameFormatters {

  // MARK: - Race name

  /// Compresses verbose race names to short form for compact display.
  ///
  /// Examples:
  ///   "Australian Grand Prix"              → "Australian GP"
  ///   "Qatar Airways Australian Grand Prix" → "Australian GP"
  ///   "Formula 1 Bahrain Grand Prix 2024"  → "Bahrain GP"
  ///   "Grand Prix of Monaco"               → "Monaco GP"
  ///   "São Paulo GP"                       → "São Paulo GP"  (already compact)
  ///   ""                                   → ""
  static func compactRaceName(from raw: String) -> String {
    guard !raw.isEmpty else { return "" }

    let s = raw.trimmingCharacters(in: .whitespaces)

    // Hard-coded: US race is held at Circuit of the Americas, not "United States"
    if s.localizedCaseInsensitiveContains("united states") { return "Americas GP" }

    // "Grand Prix of <Location>" → "<Location> GP"
    if let capRange = s.range(of: #"(?i)(?<=Grand Prix of ).+"#, options: .regularExpression) {
      let location = String(s[capRange]).trimmingCharacters(in: .whitespaces)
      return "\(location) GP"
    }

    // "GP of <Location>" → "<Location> GP"  (ESPNRacingParser pre-converts "Grand Prix" → "GP")
    if let capRange = s.range(of: #"(?i)(?<=GP of ).+"#, options: .regularExpression) {
      let location = String(s[capRange]).trimmingCharacters(in: .whitespaces)
      return "\(location) GP"
    }

    // "<Anything> <Location> Grand Prix <Optional suffix>" → "<Location> GP"
    // The word immediately before "Grand Prix" is the location.
    if let gpRange = s.range(of: "Grand Prix", options: .caseInsensitive) {
      let before = String(s[s.startIndex..<gpRange.lowerBound])
        .trimmingCharacters(in: .whitespaces)
      if let location = before.split(separator: " ").last {
        return "\(location) GP"
      }
    }

    // Already ends in " GP" — strip sponsor prefix only when input is 4+ words
    // (e.g. "Qatar Airways Australian GP" → "Australian GP").
    // 3-word inputs like "São Paulo GP" are left unchanged — "Paulo" is not the location.
    if s.hasSuffix(" GP") {
      let words = s.components(separatedBy: " ")
      if words.count <= 3 { return s }  // 2 = compact; 3 = ambiguous (two-word city like "São Paulo")
      if let location = words.dropLast().last { return "\(location) GP" }
    }

    return s
  }

  // MARK: - Live status

  /// Compresses verbose live status strings to short form for compact display.
  ///
  /// Examples:
  ///   nil / ""                                   → "LIVE"
  ///   "3rd Period - 14:32"                       → "3RD • 14:32"
  ///   "End of the 2nd Period Intermission"        → "2ND INT"
  ///   "Intermission"                             → "INT"
  ///   "Overtime"                                 → "OT"
  ///   "Shootout"                                 → "SO"
  static func compactLiveStatus(from detail: String?) -> String {
    guard let detail, !detail.isEmpty else { return "LIVE" }

    let d = detail.trimmingCharacters(in: .whitespaces)

    if d.localizedCaseInsensitiveContains("shootout")   { return "SO" }
    if d.localizedCaseInsensitiveContains("overtime")   { return "OT" }

    if d.localizedCaseInsensitiveContains("intermission") {
      if let n = periodNumber(from: d) { return "\(ordinal(n)) INT" }
      return "INT"
    }

    if d.localizedCaseInsensitiveContains("period") {
      let timePattern = #"(\d+:\d+)"#
      if let timeRange = d.range(of: timePattern, options: .regularExpression) {
        let time = String(d[timeRange])
        if let n = periodNumber(from: d) { return "\(ordinal(n)) • \(time)" }
        return "• \(time)"
      }
      if let n = periodNumber(from: d) { return ordinal(n) }
    }

    return "LIVE"
  }

  // MARK: - Private helpers

  private static func periodNumber(from s: String) -> Int? {
    guard let range = s.range(of: #"(\d+)(?:st|nd|rd|th)"#, options: [.regularExpression, .caseInsensitive]),
          let numRange = s.range(of: #"\d+"#, options: .regularExpression, range: range)
    else { return nil }
    return Int(s[numRange])
  }

  private static func ordinal(_ n: Int) -> String {
    switch n {
    case 1:  return "1ST"
    case 2:  return "2ND"
    case 3:  return "3RD"
    default: return "\(n)TH"
    }
  }
}
