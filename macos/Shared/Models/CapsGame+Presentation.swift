import Foundation

extension CapsGame {
  var streamingServicesDisplay: String {
    streamingServices.joined(separator: ", ")
  }

  var scoreboardDateLabel: String {
    Self.scoreboardDateFormatter.string(from: startTimeUTC).uppercased()
  }

  var widgetDateChipLabel: String {
    Self.widgetDateFormatter.string(from: startTimeUTC).uppercased()
  }

  var scoreboardTimeLabel: String {
    Self.scoreboardTimeFormatter.string(from: startTimeUTC).uppercased()
  }

  var scoreboardDateTimeCompactLabel: String {
    "\(scoreboardDateLabel) \(scoreboardTimeLabel)"
  }

  var liveStatusCompactLabel: String {
    guard status == .live else {
      return ""
    }

    return Self.compactLiveStatus(from: statusDetail)
  }

  var googleCalendarURL: URL? {
    let start = startTimeUTC
    let end = start.addingTimeInterval(3 * 60 * 60)
    let streamLocation = "Watch on \(streamingServicesDisplay)"

    var components = URLComponents(string: "https://calendar.google.com/calendar/render")
    components?.queryItems = [
      URLQueryItem(name: "action", value: "TEMPLATE"),
      URLQueryItem(name: "text", value: "\(awayTeam) at \(homeTeam)"),
      URLQueryItem(name: "dates", value: "\(Self.calendarTimestamp(from: start))/\(Self.calendarTimestamp(from: end))"),
      URLQueryItem(name: "details", value: "\(streamLocation)."),
      URLQueryItem(name: "location", value: streamLocation),
    ]

    return components?.url
  }

  private static func calendarTimestamp(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
    return formatter.string(from: date)
  }

  private static let scoreboardDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "MMM d"
    return formatter
  }()

  private static let scoreboardTimeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "h:mm a"
    return formatter
  }()

  private static let widgetDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .autoupdatingCurrent
    formatter.dateFormat = "MMM d"
    return formatter
  }()

  private static func compactLiveStatus(from rawDetail: String) -> String {
    let trimmed = rawDetail
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .uppercased()

    if trimmed.isEmpty {
      return "LIVE"
    }

    if trimmed.contains("SHOOTOUT") {
      return "SO"
    }

    if let intermissionPeriod = firstMatch(in: trimmed, pattern: #"(?:END OF THE )?(1ST|2ND|3RD|OT)\s*(?:PERIOD\s*)?INTERMISSION"#) {
      return "\(intermissionPeriod) INT"
    }

    if let intermissionPeriod = firstMatch(in: trimmed, pattern: #"END\s+(1ST|2ND|3RD|OT)(?:\s+PERIOD)?"#) {
      return "\(intermissionPeriod) INT"
    }

    if trimmed.contains("INTERMISSION") {
      return "INT"
    }

    let period = firstMatch(in: trimmed, pattern: #"(1ST|2ND|3RD|OT)"#)
    let clock = firstMatch(in: trimmed, pattern: #"(\d{1,2}:\d{2})"#)

    if let period, let clock {
      return "\(period) • \(clock)"
    }

    if let period {
      return period
    }

    if let clock {
      return clock
    }

    return trimmed
      .replacingOccurrences(of: " PERIOD", with: "")
      .replacingOccurrences(of: " - ", with: " • ")
  }

  private static func firstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return nil
    }

    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
      return nil
    }

    let firstGroup = match.range(at: 1)
    guard let swiftRange = Range(firstGroup, in: text) else {
      return nil
    }

    return String(text[swiftRange])
  }
}

extension Array where Element == CapsGame {
  func nextWidgetGames(now: Date = Date(), limit: Int = 3) -> [CapsGame] {
    let startOfDay = Calendar.current.startOfDay(for: now)

    return filter { game in
      (game.status == .live || game.startTimeUTC >= startOfDay) && !game.streamingServices.isEmpty
    }
    .sorted { $0.startTimeUTC < $1.startTimeUTC }
    .prefix(limit)
    .map { $0 }
  }

  func previousGames(now: Date = Date(), limit: Int = 3) -> [CapsGame] {
    filter { game in
      game.status == .final && game.startTimeUTC <= now
    }
    .sorted { $0.startTimeUTC > $1.startTimeUTC }
    .prefix(limit)
    .map { $0 }
  }

  func upcomingGames(now: Date = Date(), limit: Int = 3) -> [CapsGame] {
    filter { game in
      (game.status == .live || game.startTimeUTC >= now) && !game.streamingServices.isEmpty
    }
    .sorted { $0.startTimeUTC < $1.startTimeUTC }
    .prefix(limit)
    .map { $0 }
  }
}
