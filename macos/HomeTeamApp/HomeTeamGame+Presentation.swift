import Foundation

// MARK: - Display helpers for HomeTeamGame (app layer)

extension HomeTeamGame {

  /// "Bruins vs Rangers" or "Australian Grand Prix"
  var title: String {
    if sport.isRacing { return homeTeamName }
    return "\(homeTeamAbbrev) vs \(awayTeamAbbrev)"
  }

  /// Score, time, or status text
  var subtitle: String {
    switch status {
    case .live:
      if let h = homeScore, let a = awayScore {
        return "\(h)–\(a) · LIVE"
      }
      return statusDetail ?? "LIVE"
    case .final:
      if let h = homeScore, let a = awayScore {
        return "Final · \(h)–\(a)"
      }
      return "Final"
    case .postponed:
      return "Postponed"
    case .scheduled:
      let cal = Calendar.current
      let time = scheduledAt.formatted(date: .omitted, time: .shortened)
      if cal.isDateInToday(scheduledAt)    { return "Today · \(time)" }
      if cal.isDateInTomorrow(scheduledAt) { return "Tomorrow · \(time)" }
      let date = scheduledAt.formatted(.dateTime.month(.abbreviated).day())
      return "\(date) · \(time)"
    }
  }

  /// Whether this team's entry should be suppressed during off-season
  var isOffseason: Bool {
    let now = Date()
    let daysTilNext = scheduledAt.timeIntervalSince(now) / 86400
    // >45 days to next game OR hasn't played in >30 days
    if daysTilNext > 45 { return true }
    return false
  }
}

// SupportedSport.isRacing and .displayName are defined in TeamCatalog.swift
