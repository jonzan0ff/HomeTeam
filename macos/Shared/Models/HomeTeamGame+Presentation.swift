import Foundation
import SwiftUI
import AppKit

extension HomeTeamGame {
  func preferredStreamingService(selectedServiceLookup: Set<String>) -> String? {
    let matchedServices = StreamingServiceMatcher.matchedServices(from: streamingServices)

    if selectedServiceLookup.isEmpty {
      return matchedServices.first ?? streamingServices.first
    }

    if let matched = matchedServices.first(where: { service in
      selectedServiceLookup.contains(AppSettings.normalizedServiceName(service))
    }) {
      return matched
    }

    if matchedServices.isEmpty {
      return streamingServices.first
    }

    return matchedServices.first
  }

  func passesStreamingFilter(selectedServiceLookup: Set<String>) -> Bool {
    guard !selectedServiceLookup.isEmpty else {
      return true
    }

    let matchedServices = StreamingServiceMatcher.matchedServices(from: streamingServices)
    guard !matchedServices.isEmpty else {
      // When a user selects services, only explicit provider matches should pass.
      return false
    }

    return matchedServices
      .map(AppSettings.normalizedServiceName)
      .contains(where: selectedServiceLookup.contains)
  }

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

  var raceResultHeaderLabel: String {
    guard status == .final else {
      return "Final"
    }

    guard sport == .f1 || sport == .motogp else {
      return "Final"
    }

    let compact = Self.compactRaceName(from: homeTeam)
    return compact.isEmpty ? "Final" : compact
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

  private static func compactRaceName(from rawName: String) -> String {
    let trimmed = rawName
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

    guard !trimmed.isEmpty else {
      return ""
    }

    if let match = firstGroupMatch(in: trimmed, pattern: #"(?i)\b([A-Za-z]+(?:\s+[A-Za-z]+)?)\s+Grand Prix\b"#) {
      return compactSponsorPrefix(in: "\(match) GP")
    }

    if let match = firstGroupMatch(in: trimmed, pattern: #"(?i)\bGrand Prix of\s+([A-Za-z]+(?:\s+[A-Za-z]+)?)\b"#) {
      return compactSponsorPrefix(in: "\(match) GP")
    }

    if let match = firstGroupMatch(in: trimmed, pattern: #"(?i)\b(.+?)\s+GP\b"#) {
      return compactSponsorPrefix(in: "\(match) GP")
    }

    var normalized = trimmed
    normalized = normalized.replacingOccurrences(of: #"(?i)^Formula\s*1\s+"#, with: "", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: #"(?i)\bMotoGP\b"#, with: "", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: #"(?i)\bGrand Prix\b"#, with: "GP", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: #"(?i)\bof\b"#, with: "", options: .regularExpression)
    normalized = normalized.replacingOccurrences(of: #"\b20\d{2}\b"#, with: "", options: .regularExpression)
    normalized = normalized
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return compactSponsorPrefix(in: normalized)
  }

  private static func compactSponsorPrefix(in label: String) -> String {
    let sponsorPrefixes = [
      "Qatar Airways ",
      "Heineken ",
      "Aramco ",
      "Gulf Air ",
      "STC ",
      "Crypto.com ",
      "Lenovo ",
      "MSC Cruises ",
      "Pirelli ",
      "AWS ",
      "Tag Heuer ",
      "Etihad Airways ",
      "Singapore Airlines ",
    ]

    var compact = label.trimmingCharacters(in: .whitespacesAndNewlines)
    for prefix in sponsorPrefixes where compact.lowercased().hasPrefix(prefix.lowercased()) {
      compact.removeFirst(prefix.count)
      break
    }

    return compact
      .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
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

  private static func firstGroupMatch(in text: String, pattern: String) -> String? {
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

    return String(text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

extension Array where Element == HomeTeamGame {
  func nextWidgetGames(
    now: Date = Date(),
    limit: Int = 3
  ) -> [HomeTeamGame] {
    let startOfDay = Calendar.current.startOfDay(for: now)

    return filter { game in
      game.status == .live || game.startTimeUTC >= startOfDay
    }
    .sorted { $0.startTimeUTC < $1.startTimeUTC }
    .prefix(limit)
    .map { $0 }
  }

  func previousGames(now: Date = Date(), limit: Int = 3) -> [HomeTeamGame] {
    let calendar = Calendar(identifier: .gregorian)
    let seasonYearForRacing = inferredRacingSeasonYear(now: now, calendar: calendar)

    let finalized = filter { game in
      game.status == .final && game.startTimeUTC <= now
    }
    .filter { game in
      guard let seasonYearForRacing else {
        return true
      }
      return calendar.component(.year, from: game.startTimeUTC) == seasonYearForRacing
    }

    return finalized
    .sorted { $0.startTimeUTC > $1.startTimeUTC }
    .prefix(limit)
    .map { $0 }
  }

  func upcomingGames(
    now: Date = Date(),
    limit: Int = 3,
    selectedServiceLookup: Set<String> = []
  ) -> [HomeTeamGame] {
    let sortedUpcoming = filter { game in
      game.status == .live || (game.status != .final && game.startTimeUTC >= now)
    }
    .filter { game in
      game.isAllowedMotoGPUpcomingSession
    }
    .sorted { $0.startTimeUTC < $1.startTimeUTC }

    let filtered = selectedServiceLookup.isEmpty
      ? sortedUpcoming
      : sortedUpcoming.filter { $0.passesStreamingFilter(selectedServiceLookup: selectedServiceLookup) }

    return filtered
      .prefix(limit)
      .map { $0 }
  }

  private func inferredRacingSeasonYear(now: Date, calendar: Calendar) -> Int? {
    let explicitSports = Set(compactMap(\.sport))
    let explicitRacingSports = explicitSports.filter { $0 == .f1 || $0 == .motogp }
    let hasRacingLabelSignals = contains { $0.looksLikeRacingEvent }
    guard explicitRacingSports.count == 1 || (explicitRacingSports.isEmpty && hasRacingLabelSignals) else {
      return nil
    }

    if let firstUpcoming = self
      .filter({ $0.startTimeUTC >= now })
      .min(by: { $0.startTimeUTC < $1.startTimeUTC })
    {
      return calendar.component(.year, from: firstUpcoming.startTimeUTC)
    }

    // Prefer the current calendar year when the dataset already has racing
    // rows in-year but no strictly future timestamps (legacy/offline snapshots).
    let currentYear = calendar.component(.year, from: now)
    if contains(where: { calendar.component(.year, from: $0.startTimeUTC) == currentYear }) {
      return currentYear
    }

    if let mostRecent = self
      .filter({ $0.startTimeUTC <= now })
      .max(by: { $0.startTimeUTC < $1.startTimeUTC })
    {
      return calendar.component(.year, from: mostRecent.startTimeUTC)
    }

    return nil
  }
}

private extension HomeTeamGame {
  var isAllowedMotoGPUpcomingSession: Bool {
    guard sport == .motogp else {
      return true
    }

    let normalized = homeTeam
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()

    if normalized.contains("sprint") {
      return true
    }
    if normalized.contains("grand prix") || normalized.hasSuffix(" gp") {
      return true
    }
    if normalized == "race" || normalized.contains(" main race") {
      return true
    }

    return false
  }

  var looksLikeRacingEvent: Bool {
    if sport == .f1 || sport == .motogp {
      return true
    }

    let normalized = homeTeam
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    return normalized.contains("grand prix")
      || normalized.hasSuffix(" gp")
      || normalized.contains("motogp")
      || normalized.contains("formula 1")
  }
}

struct HomeTeamWidgetContentState {
  let referenceDate: Date
  let snapshot: ScheduleSnapshot
  let settings: AppSettings
  let team: TeamDefinition
  let isTeamSelectionConfigured: Bool

  var widgetTitleText: String {
    isTeamSelectionConfigured ? team.displayName : "Choose HomeTeam"
  }

  /// True when the user has streaming picks that remove every upcoming game, while unfiltered upcoming still exists.
  var upcomingHiddenByStreamingFilter: Bool {
    guard isTeamSelectionConfigured else {
      return false
    }
    let lookup = settings.selectedServiceLookup
    guard !lookup.isEmpty else {
      return false
    }
    let raw = snapshot.games.upcomingGames(now: referenceDate, limit: 20, selectedServiceLookup: [])
    let filtered = snapshot.games.upcomingGames(now: referenceDate, limit: 20, selectedServiceLookup: lookup)
    return !raw.isEmpty && filtered.isEmpty
  }

  var widgetEmptyStateMessage: (title: String, detail: String) {
    guard isTeamSelectionConfigured else {
      if TeamCatalog.widgetConfigurationTeams(settings: settings).isEmpty {
        return (
          "Add favorites in HomeTeam",
          "Then right-click this widget and choose Edit \"HomeTeam\"."
        )
      }
      return (
        "Widget not configured",
        "Right-click this widget and choose Edit \"HomeTeam\"."
      )
    }

    if
      let errorMessage = snapshot.errorMessage?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !errorMessage.isEmpty
    {
      return ("Unable to load games", errorMessage)
    }

    let previousShown = snapshot.games.previousGames(now: referenceDate, limit: 3)
    let filteredUpcoming = snapshot.games.upcomingGames(
      now: referenceDate,
      limit: 3,
      selectedServiceLookup: settings.selectedServiceLookup
    )
    let rawUpcoming = snapshot.games.upcomingGames(
      now: referenceDate,
      limit: 3,
      selectedServiceLookup: []
    )

    if previousShown.isEmpty && filteredUpcoming.isEmpty {
      if upcomingHiddenByStreamingFilter {
        return (
          "Upcoming hidden by streaming filters",
          "Open HomeTeam Settings and add providers that carry this team, or broaden your streaming picks."
        )
      }

      if !snapshot.games.isEmpty {
        return (
          "Schedule is still catching up",
          "The feed has events that are not shown as previous or upcoming yet. Open HomeTeam to refresh."
        )
      }
    }

    return ("No games available", "Open the app to refresh.")
  }
}

enum HomeTeamWidgetBackground {
  static let gradient = LinearGradient(
    colors: [
      Color(red: 0.05, green: 0.07, blue: 0.12),
      Color(red: 0.03, green: 0.04, blue: 0.08),
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}

struct HomeTeamWidgetContentView: View {
  let state: HomeTeamWidgetContentState

  private var previousGames: [HomeTeamGame] {
    state.snapshot.games.previousGames(now: state.referenceDate, limit: 3)
  }

  private var upcomingGames: [HomeTeamGame] {
    state.snapshot.games.upcomingGames(
      now: state.referenceDate,
      limit: 3,
      selectedServiceLookup: state.settings.selectedServiceLookup
    )
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(state.widgetTitleText)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.88))
        .lineLimit(1)

      if let summary = state.snapshot.teamSummary?.inlineDisplay {
        Text(summary)
          .font(.caption2.weight(.medium))
          .foregroundStyle(.white.opacity(0.66))
          .lineLimit(1)
      }

      if previousGames.isEmpty && upcomingGames.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text(state.widgetEmptyStateMessage.title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))

          Text(state.widgetEmptyStateMessage.detail)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.62))
            .lineLimit(3)
        }
      } else {
        WidgetSectionRow(
          title: "Previous",
          games: previousGames,
          rowType: .previous,
          selectedServiceLookup: state.settings.selectedServiceLookup,
          emptyUpcomingBecauseStreamingFilter: false
        )
        WidgetSectionRow(
          title: "Upcoming",
          games: upcomingGames,
          rowType: .upcoming,
          selectedServiceLookup: state.settings.selectedServiceLookup,
          emptyUpcomingBecauseStreamingFilter: state.upcomingHiddenByStreamingFilter
        )
      }

      Spacer(minLength: 0)

      HStack {
        Spacer()
        Text("Updated \(state.snapshot.lastUpdated.formatted(date: .omitted, time: .shortened))")
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .truncationMode(.tail)
          .foregroundStyle(.white.opacity(0.72))
      }
    }
    .padding(8)
  }
}

private enum WidgetRowType {
  case previous
  case upcoming
}

private struct WidgetSectionRow: View {
  let title: String
  let games: [HomeTeamGame]
  let rowType: WidgetRowType
  let selectedServiceLookup: Set<String>
  let emptyUpcomingBecauseStreamingFilter: Bool

  private var emptyRowPlaceholder: String {
    switch rowType {
    case .previous:
      return "No finals"
    case .upcoming:
      if emptyUpcomingBecauseStreamingFilter {
        return "None match your streaming picks"
      }
      return "No upcoming"
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption2.weight(.bold))
        .textCase(.uppercase)
        .foregroundStyle(.white.opacity(0.62))

      if games.isEmpty {
        Text(emptyRowPlaceholder)
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.54))
      } else {
        HStack(spacing: 6) {
          ForEach(games.prefix(3)) { game in
            WidgetGameCard(
              game: game,
              rowType: rowType,
              selectedServiceLookup: selectedServiceLookup
            )
          }
        }
      }
    }
  }
}

private struct WidgetGameCard: View {
  let game: HomeTeamGame
  let rowType: WidgetRowType
  let selectedServiceLookup: Set<String>

  private var leadingChipLabel: String {
    game.widgetDateChipLabel
  }

  private var primaryService: String {
    game.preferredStreamingService(selectedServiceLookup: selectedServiceLookup) ?? "Stream"
  }

  private var trailingValueAway: String {
    trailingValue(score: game.awayScore, record: game.awayRecord, status: game.status)
  }

  private var trailingValueHome: String {
    trailingValue(score: game.homeScore, record: game.homeRecord, status: game.status)
  }

  private var headerTrailingText: String {
    switch game.status {
    case .scheduled:
      return game.scoreboardTimeLabel
    case .live:
      return game.liveStatusCompactLabel
    case .final:
      return game.raceResultHeaderLabel
    }
  }

  private var awayIsLeader: Bool {
    guard
      game.status != .scheduled,
      let awayScore = game.awayScore,
      let homeScore = game.homeScore
    else {
      return false
    }

    return awayScore > homeScore
  }

  private var homeIsLeader: Bool {
    guard
      game.status != .scheduled,
      let awayScore = game.awayScore,
      let homeScore = game.homeScore
    else {
      return false
    }

    return homeScore > awayScore
  }

  private var showsRacingResults: Bool {
    (game.sport == .f1 || game.sport == .motogp)
      && !(game.racingResults?.isEmpty ?? true)
  }

  private var showsRacingUpcomingEventName: Bool {
    rowType == .upcoming
      && game.status == .scheduled
      && !showsRacingResults
      && game.homeAbbrev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && game.awayAbbrev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Text(leadingChipLabel)
          .font(.system(size: 9, weight: .bold, design: .default))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .allowsTightening(true)
          .monospacedDigit()
          .truncationMode(.tail)
          .frame(width: 37, alignment: .center)
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(
            Capsule(style: .continuous)
              .fill(Color.white.opacity(0.16))
          )
          .foregroundStyle(Color.white.opacity(0.9))

        Spacer(minLength: 0)

        Text(headerTrailingText)
          .font(.system(size: 8, weight: .semibold, design: .default))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .truncationMode(.tail)
          .foregroundStyle(.white.opacity(0.7))
      }

      if showsRacingResults, let lines = game.racingResults {
        WidgetRacingResults(lines: lines, sport: game.sport)
      } else if showsRacingUpcomingEventName {
        Text(game.homeTeam)
          .font(.system(size: 8.5, weight: .semibold, design: .default))
          .lineLimit(2)
          .foregroundStyle(.white.opacity(0.9))

        upcomingFooter
      } else {
        VStack(spacing: 4) {
          if !game.awayAbbrev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            CompactTeamRow(abbrev: game.awayAbbrev, logoURL: game.awayLogoURL, sport: game.sport, isLeader: awayIsLeader, trailingValue: trailingValueAway)
          }
          if !game.homeAbbrev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            CompactTeamRow(abbrev: game.homeAbbrev, logoURL: game.homeLogoURL, sport: game.sport, isLeader: homeIsLeader, trailingValue: trailingValueHome)
          }
        }

        upcomingFooter
      }
    }
    .padding(6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(Color.white.opacity(0.09))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(Color.white.opacity(0.14), lineWidth: 1)
    )
  }

  @ViewBuilder
  private var upcomingFooter: some View {
    if rowType == .upcoming {
      HStack(spacing: 6) {
        ServiceLogoView(service: primaryService, sport: game.sport)
      }
    }
  }

  private func trailingValue(score: Int?, record: String?, status: GameStatus) -> String {
    if
      rowType == .upcoming,
      status == .scheduled,
      (game.sport == .f1 || game.sport == .motogp)
    {
      return ""
    }

    if rowType == .previous || status != .scheduled {
      if let score {
        return "\(score)"
      }
      return record ?? "-"
    }

    return record ?? "-"
  }
}

private struct WidgetRacingResults: View {
  let lines: [RacingResultLine]
  let sport: SupportedSport?

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      ForEach(lines) { line in
        HStack(spacing: 4) {
          Text("\(line.place)")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(.white.opacity(0.9))
            .frame(width: 10, alignment: .leading)
          TeamMarkView(abbrev: line.teamAbbrev, logoURL: line.teamLogoURL, sport: sport, isLeader: line.isFavorite)
          Text("\(line.driver) \(line.teamAbbrev)")
            .font(.system(size: 8, weight: line.isFavorite ? .bold : .regular))
            .foregroundStyle(line.isFavorite ? Color.white : Color.white.opacity(0.86))
            .lineLimit(1)
          Spacer(minLength: 0)
        }
      }
    }
  }
}

private struct CompactTeamRow: View {
  let abbrev: String
  let logoURL: String?
  let sport: SupportedSport?
  let isLeader: Bool
  let trailingValue: String

  var body: some View {
    HStack(spacing: 5) {
      TeamMarkView(abbrev: abbrev, logoURL: logoURL, sport: sport, isLeader: isLeader)
      Spacer(minLength: 2)
      if !trailingValue.isEmpty {
        HStack(spacing: 2) {
          Text(trailingValue)
            .font(.caption2.weight(isLeader ? .bold : .regular))
            .foregroundStyle(isLeader ? Color.white : Color.white.opacity(0.85))
            .monospacedDigit()
          Image(systemName: "arrowtriangle.left.fill")
            .font(.system(size: 5.5, weight: .bold))
            .foregroundStyle(Color.white.opacity(isLeader ? 0.88 : 0.0))
            .frame(width: 4, alignment: .center)
        }
      }
    }
  }
}

private struct TeamMarkView: View {
  private let teamLogoStore = TeamLogoStore()
  let abbrev: String
  let logoURL: String?
  let sport: SupportedSport?
  let isLeader: Bool

  private var shortAbbrev: String {
    String(abbrev.prefix(3)).uppercased()
  }

  var body: some View {
    HStack(spacing: 3) {
      if let image = teamLogoStore.cachedImage(for: logoURL, teamAbbrev: abbrev, sport: sport) {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
          .frame(width: 12, height: 12)
      } else {
        Circle()
          .fill(Color.white.opacity(0.18))
          .overlay(
            Text(String(shortAbbrev.prefix(1)))
              .font(.system(size: 7, weight: .bold))
              .foregroundStyle(.white.opacity(0.92))
          )
          .frame(width: 12, height: 12)
      }

      Text(shortAbbrev)
        .font(.caption2.weight(isLeader ? .bold : .regular))
        .foregroundStyle(isLeader ? Color.white : Color.white.opacity(0.84))
    }
  }
}

private struct ServiceLogoView: View {
  private let teamLogoStore = TeamLogoStore()
  let service: String
  let sport: SupportedSport?

  private var normalizedService: String {
    service.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
  }

  private var badgeText: String {
    let upper = normalizedService
    if upper.contains("HULU TV") || upper.contains("HULU LIVE") || (upper.contains("HULU") && upper.contains("LIVE")) {
      return "HULU TV"
    }
    if upper.contains("HULU") {
      return "HULU"
    }
    if upper.contains("ESPN") {
      return "ESPN+"
    }
    if upper.contains("PARAMOUNT") {
      return "PARAMOUNT+"
    }
    if upper.contains("AMAZON") || upper.contains("PRIME") {
      return "PRIME"
    }
    if upper.contains("PEACOCK") {
      return "PEACOCK"
    }
    if upper.contains("HBO") || upper.contains("MAX") {
      return "HBO"
    }
    if upper.contains("APPLE") {
      return "TV+"
    }
    if upper.contains("YOUTUBE") {
      return "YT TV"
    }
    if upper.contains("NETFLIX") {
      return "NETFLIX"
    }

    if upper.isEmpty {
      return "TV"
    }

    return String(upper.prefix(10))
  }

  private var backgroundColor: Color {
    let upper = normalizedService
    if upper.contains("HULU") {
      return Color(red: 0.09, green: 0.74, blue: 0.46)
    }
    if upper.contains("ESPN") {
      return Color(red: 0.79, green: 0.14, blue: 0.16)
    }
    if upper.contains("PARAMOUNT") {
      return Color(red: 0.10, green: 0.40, blue: 0.85)
    }
    if upper.contains("AMAZON") || upper.contains("PRIME") {
      return Color(red: 0.12, green: 0.46, blue: 0.82)
    }
    if upper.contains("PEACOCK") {
      return Color(red: 0.95, green: 0.58, blue: 0.10)
    }
    if upper.contains("HBO") || upper.contains("MAX") {
      return Color(red: 0.45, green: 0.26, blue: 0.85)
    }
    if upper.contains("APPLE") {
      return Color.white.opacity(0.22)
    }
    if upper.contains("YOUTUBE") {
      return Color(red: 0.86, green: 0.16, blue: 0.16)
    }
    if upper.contains("NETFLIX") {
      return Color(red: 0.78, green: 0.12, blue: 0.16)
    }
    return Color.white.opacity(0.2)
  }

  var body: some View {
    HStack(spacing: 3) {
      if normalizedService.contains("APPLE") {
        Image(systemName: "applelogo")
          .resizable()
          .scaledToFit()
          .frame(width: 9, height: 9)
      } else if
        let logoURL = StreamingProviderLogoCatalog.logoURL(for: service),
        let image = teamLogoStore.cachedImage(for: logoURL, sport: sport)
      {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
          .frame(width: 9, height: 9)
      }

      Text(badgeText)
        .font(.system(size: badgeText.count > 8 ? 6.8 : 7.5, weight: .black, design: .rounded))
        .foregroundStyle(.white.opacity(0.96))
        .lineLimit(1)
    }
    .padding(.horizontal, 3)
    .padding(.vertical, 1)
    .background(
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(backgroundColor)
    )
  }
}
