import SwiftUI
import WidgetKit

// MARK: - Root view

struct HomeTeamWidgetEntryView: View {
  let entry: HomeTeamEntry
  @Environment(\.colorScheme) private var colorScheme

  private var isDark: Bool { colorScheme == .dark }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if entry.teamDefinition == nil && entry.isEmpty {
        UnconfiguredView()
      } else if entry.isEmpty {
        NoGamesView()
      } else {
        if let team = entry.teamDefinition {
          TeamHeader(team: team, summary: entry.teamSummary, isDark: isDark)
          Divider().opacity(isDark ? 0.18 : 0.2)
        }
        SectionRow(
          title: "PREVIOUS",
          games: entry.previousGames,
          emptyText: "No finals",
          isOffSeason: false,
          favoriteDriverNames: entry.teamDefinition?.driverNames ?? [],
          isDark: isDark
        )
        SectionRow(
          title: "UPCOMING",
          games: entry.allUpcoming,
          emptyText: upcomingEmptyText,
          isOffSeason: entry.isOffSeason,
          favoriteDriverNames: entry.teamDefinition?.driverNames ?? [],
          isDark: isDark
        )
        .padding(.top, 4)
        Spacer(minLength: 0)
        footerView
      }
    }
    .padding(8)
  }

  private var upcomingEmptyText: String {
    guard let team = entry.teamDefinition else { return "No upcoming" }
    if entry.isOffSeason { return "\(team.name) Off-season" }
    return "No upcoming"
  }

  private var footerView: some View {
    HStack {
      Spacer()
      if entry.fetchedAt != .distantPast {
        Text("Updated \(entry.fetchedAt.formatted(.dateTime.hour().minute()))")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(isDark ? Color.white.opacity(0.72) : Color.secondary)
      }
    }
  }
}

// MARK: - Team header

private struct TeamHeader: View {
  let team: TeamDefinition
  let summary: HomeTeamTeamSummary?
  let isDark: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack(spacing: 8) {
        if let nsImage = AppGroupStore.logoFileURL(sport: team.sport, espnTeamID: team.espnTeamID)
            .flatMap({ NSImage(contentsOf: $0) }) {
          Image(nsImage: nsImage)
            .resizable().aspectRatio(contentMode: .fit)
            .frame(width: 30, height: 30)
        } else if team.sport.isRacing {
          Image(systemName: team.sport.systemImageName)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(isDark ? Color.white.opacity(0.75) : Color.primary.opacity(0.75))
            .frame(width: 30, height: 30)
        } else {
          Circle()
            .fill(isDark ? Color.white.opacity(0.15) : Color.primary.opacity(0.12))
            .overlay(
              Text(String(team.abbreviation.prefix(1)).uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isDark ? Color.white.opacity(0.7) : Color.primary.opacity(0.7))
            )
            .frame(width: 30, height: 30)
        }

        Text(team.raceLabel)
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(isDark ? Color.white : Color.primary)
          .lineLimit(1)

        if summary == nil {
          Text(team.sport.displayName)
            .font(.caption2)
            .foregroundStyle(isDark ? Color.white.opacity(0.55) : Color.secondary)
        }

        Spacer(minLength: 0)
      }

      if let summary {
        Text(summary.inlineDisplay)
          .font(.system(size: 10.5, weight: .medium))
          .foregroundStyle(isDark ? Color.white.opacity(0.62) : Color.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.65)
      }
    }
  }
}

// MARK: - Section row

private struct SectionRow: View {
  let title: String
  let games: [HomeTeamGame]
  let emptyText: String
  let isOffSeason: Bool
  let favoriteDriverNames: [String]
  let isDark: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption2.weight(.bold))
        .textCase(.uppercase)
        .foregroundStyle(isDark ? Color.white.opacity(0.62) : Color.secondary)

      if games.isEmpty {
        if isOffSeason {
          HStack(spacing: 5) {
            Image(systemName: "zzz")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(isDark ? Color.white.opacity(0.54) : Color.secondary)
            Text(emptyText)
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(isDark ? Color.white.opacity(0.54) : Color.secondary)
              .lineLimit(1)
              .minimumScaleFactor(0.75)
          }
        } else {
          Text(emptyText)
            .font(.caption2)
            .foregroundStyle(isDark ? Color.white.opacity(0.54) : Color.secondary)
        }
      } else {
        HStack(spacing: 6) {
          ForEach(games.prefix(3)) { game in
            GameCard(
              game: game,
              isPrevious: title == "PREVIOUS",
              favoriteDriverNames: favoriteDriverNames,
              isDark: isDark
            )
          }
        }
      }
    }
  }
}

// MARK: - Game card

private struct GameCard: View {
  let game: HomeTeamGame
  let isPrevious: Bool
  let favoriteDriverNames: [String]
  let isDark: Bool

  private var isLive: Bool { game.status == .live }
  private var isRacing: Bool { game.sport.isRacing }

  private var chipLabel: String {
    switch game.status {
    case .live:      return "LIVE"
    case .final:     return "FINAL"
    case .postponed: return "PPD"
    case .scheduled:
      let cal = Calendar.current
      if cal.isDateInToday(game.scheduledAt)    { return "TODAY" }
      if cal.isDateInTomorrow(game.scheduledAt) { return "TMRW" }
      return game.scheduledAt.formatted(.dateTime.month(.abbreviated).day())
    }
  }

  // Score is shown in team rows — header only shows time/status for non-final
  private var statusLabel: String {
    switch game.status {
    case .scheduled:
      return game.scheduledAt.formatted(.dateTime.hour().minute())
    case .live:
      return GameFormatters.compactLiveStatus(from: game.statusDetail)
    case .final, .postponed:
      return ""
    }
  }

  private var awayLeads: Bool {
    guard game.status != .scheduled, let a = game.awayScore, let h = game.homeScore else { return false }
    return a > h
  }
  private var homeLeads: Bool {
    guard game.status != .scheduled, let a = game.awayScore, let h = game.homeScore else { return false }
    return h > a
  }

  private func trailingValue(score: Int?, record: String?) -> String {
    if isRacing { return "" }
    if game.status != .scheduled, let s = score { return "\(s)" }
    return record ?? ""
  }

  private func teamLogoImage(espnTeamID: String) -> NSImage? {
    AppGroupStore.logoFileURL(sport: game.sport, espnTeamID: espnTeamID)
      .flatMap { NSImage(contentsOf: $0) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Header: date chip + status
      HStack(spacing: 4) {
        Text(chipLabel)
          .font(.system(size: 9, weight: .bold))
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .monospacedDigit()
          .padding(.horizontal, 5)
          .padding(.vertical, 2)
          .background(
            Capsule(style: .continuous)
              .fill(isDark ? Color.white.opacity(0.16) : Color.primary.opacity(0.1))
          )
          .foregroundStyle(isDark ? Color.white.opacity(0.9) : Color.primary)

        Spacer(minLength: 0)

        if !statusLabel.isEmpty {
          Text(statusLabel)
            .font(.system(size: 8, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(isLive ? Color.green : (isDark ? Color.white.opacity(0.7) : Color.secondary))
        }
      }

      // Body
      if isRacing && !(game.racingResults?.isEmpty ?? true), let results = game.racingResults {
        RacingResultsView(results: results, favoriteDriverNames: favoriteDriverNames, isDark: isDark)
      } else if isRacing {
        Text(GameFormatters.compactRaceName(from: game.homeTeamName))
          .font(.system(size: 8.5, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .foregroundStyle(isDark ? Color.white.opacity(0.9) : Color.primary)
      } else {
        VStack(spacing: 4) {
          if !game.awayTeamAbbrev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            TeamRow(
              abbrev: game.awayTeamAbbrev,
              trailing: trailingValue(score: game.awayScore, record: game.awayRecord),
              isLeader: awayLeads,
              logoImage: teamLogoImage(espnTeamID: game.awayTeamID),
              isDark: isDark
            )
          }
          if !game.homeTeamAbbrev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            TeamRow(
              abbrev: game.homeTeamAbbrev,
              trailing: trailingValue(score: game.homeScore, record: game.homeRecord),
              isLeader: homeLeads,
              logoImage: teamLogoImage(espnTeamID: game.homeTeamID),
              isDark: isDark
            )
          }
        }
      }

      // Streaming badge (upcoming only)
      if !isPrevious, let network = game.broadcastNetworks.first {
        ServiceBadge(name: network, isDark: isDark)
      }
    }
    .padding(6)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(isDark ? Color.white.opacity(0.09) : Color.primary.opacity(0.06))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .stroke(
          isLive
            ? Color.red.opacity(0.55)
            : (isDark ? Color.white.opacity(0.14) : Color.primary.opacity(0.12)),
          lineWidth: 1
        )
    )
  }
}

// MARK: - Team row

private struct TeamRow: View {
  let abbrev: String
  let trailing: String
  let isLeader: Bool
  let logoImage: NSImage?
  let isDark: Bool

  var body: some View {
    HStack(spacing: 5) {
      Group {
        if let nsImage = logoImage {
          Image(nsImage: nsImage)
            .resizable().aspectRatio(contentMode: .fit)
        } else {
          Circle()
            .fill(isDark ? Color.white.opacity(0.18) : Color.primary.opacity(0.14))
            .overlay(
              Text(String(abbrev.prefix(1)).uppercased())
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(isDark ? Color.white.opacity(0.92) : Color.primary.opacity(0.8))
            )
        }
      }
      .frame(width: 14, height: 14)
      .clipShape(Circle())

      Text(String(abbrev.prefix(3)).uppercased())
        .font(.caption2.weight(isLeader ? .bold : .regular))
        .foregroundStyle(
          isLeader
            ? (isDark ? Color.white : Color.primary)
            : (isDark ? Color.white.opacity(0.84) : Color.primary.opacity(0.75))
        )

      Spacer(minLength: 2)

      if !trailing.isEmpty {
        HStack(spacing: 2) {
          Text(trailing)
            .font(.caption2.weight(isLeader ? .bold : .regular))
            .foregroundStyle(
              isLeader
                ? (isDark ? Color.white : Color.primary)
                : (isDark ? Color.white.opacity(0.85) : Color.primary.opacity(0.75))
            )
            .monospacedDigit()
          Image(systemName: "arrowtriangle.left.fill")
            .font(.system(size: 5.5, weight: .bold))
            .foregroundStyle(
              (isDark ? Color.white : Color.primary)
                .opacity(isLeader ? 0.88 : 0.0)
            )
            .frame(width: 4)
        }
      }
    }
  }
}

// MARK: - Racing results

private struct RacingResultsView: View {
  let results: [RacingResultLine]
  let favoriteDriverNames: [String]
  let isDark: Bool

  private func isFavorite(_ line: RacingResultLine) -> Bool {
    guard !favoriteDriverNames.isEmpty else { return false }
    let name = line.driverName.lowercased()
    return favoriteDriverNames.contains { name.contains($0.lowercased()) || $0.lowercased().contains(name) }
  }

  // Show P1/P2/P3 always; append favorite driver if they finished outside top 3
  private var displayLines: [RacingResultLine] {
    let top3 = Array(results.prefix(3))
    if top3.contains(where: { isFavorite($0) }) { return top3 }
    if let fav = results.dropFirst(3).first(where: { isFavorite($0) }) {
      return top3 + [fav]
    }
    return top3
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      ForEach(displayLines) { line in
        let fav = isFavorite(line)
        HStack(spacing: 4) {
          Text("\(line.position)")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(isDark ? Color.white.opacity(0.9) : Color.primary)
            .frame(width: 10, alignment: .leading)
          Text(line.driverName)
            .font(.system(size: 8, weight: fav ? .bold : .regular))
            .foregroundStyle(
              isDark
                ? (fav ? Color.white : Color.white.opacity(0.86))
                : (fav ? Color.primary : Color.primary.opacity(0.75))
            )
            .lineLimit(1)
          Spacer(minLength: 0)
        }
      }
    }
  }
}

// MARK: - Streaming service badge

private struct ServiceBadge: View {
  let name: String
  let isDark: Bool

  private var upper: String { name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }

  private var label: String {
    if upper.contains("HULU") && upper.contains("LIVE") { return "HULU TV" }
    if upper.contains("HULU")        { return "HULU" }
    if upper.contains("ESPN+") || upper == "ESPNPLUS" { return "ESPN+" }
    if upper.contains("ESPN2")       { return "ESPN2" }
    if upper.contains("ESPN")        { return "ESPN" }
    if upper.contains("FS1")         { return "FS1" }
    if upper.contains("FS2")         { return "FS2" }
    if upper.contains("PARAMOUNT")   { return "PARAMOUNT+" }
    if upper.contains("AMAZON") || upper.contains("PRIME") { return "PRIME" }
    if upper.contains("PEACOCK")     { return "PEACOCK" }
    if upper.contains("HBO") || upper.contains("MAX") || upper.contains("TNT") { return "MAX" }
    if upper.contains("TBS")         { return "TBS" }
    if upper.contains("APPLE")       { return "TV+" }
    if upper.contains("YOUTUBE")     { return "YT TV" }
    if upper.contains("NETFLIX")     { return "NETFLIX" }
    if upper.contains("NBC")         { return "NBC" }
    if upper.contains("CBS")         { return "CBS" }
    if upper.contains("ABC")         { return "ABC" }
    if upper.contains("FOX")         { return "FOX" }
    if upper.contains("DAZN")        { return "DAZN" }
    if upper.contains("F1 TV") || upper.contains("F1TV") { return "F1 TV" }
    if upper.isEmpty { return "TV" }
    return String(upper.prefix(8))
  }

  // All colors are dark enough to show white text on both light and dark widget backgrounds
  private var badgeColor: Color {
    if upper.contains("HULU")                              { return Color(red: 0.09, green: 0.74, blue: 0.46) }
    if upper.contains("ESPN")                              { return Color(red: 0.79, green: 0.14, blue: 0.16) }
    if upper.contains("FS1") || upper.contains("FS2")      { return Color(red: 0.82, green: 0.28, blue: 0.04) }
    if upper.contains("FOX")                               { return Color(red: 0.82, green: 0.28, blue: 0.04) }
    if upper.contains("PARAMOUNT")                         { return Color(red: 0.10, green: 0.40, blue: 0.85) }
    if upper.contains("AMAZON") || upper.contains("PRIME") { return Color(red: 0.12, green: 0.46, blue: 0.82) }
    if upper.contains("PEACOCK")                           { return Color(red: 0.80, green: 0.44, blue: 0.00) }
    if upper.contains("HBO") || upper.contains("MAX") || upper.contains("TNT") {
      return Color(red: 0.45, green: 0.26, blue: 0.85)
    }
    if upper.contains("TBS")                               { return Color(red: 0.20, green: 0.48, blue: 0.76) }
    if upper.contains("YOUTUBE")                           { return Color(red: 0.86, green: 0.16, blue: 0.16) }
    if upper.contains("NETFLIX")                           { return Color(red: 0.78, green: 0.12, blue: 0.16) }
    if upper.contains("APPLE")                             { return Color(red: 0.30, green: 0.30, blue: 0.33) }
    if upper.contains("NBC")                               { return Color(red: 0.15, green: 0.30, blue: 0.75) }
    if upper.contains("CBS")                               { return Color(red: 0.08, green: 0.18, blue: 0.62) }
    if upper.contains("ABC")                               { return Color(red: 0.08, green: 0.08, blue: 0.48) }
    if upper.contains("DAZN")                              { return Color(red: 0.92, green: 0.08, blue: 0.16) }
    if upper.contains("F1 TV") || upper.contains("F1TV")   { return Color(red: 0.88, green: 0.08, blue: 0.16) }
    return Color(red: 0.25, green: 0.25, blue: 0.28)  // dark neutral — readable on both light and dark
  }

  // Colored pill + white text: visible on dark and light widget backgrounds.
  // Survives OS-level desaturation (dimmed) — gray background + white text stays readable.

  var body: some View {
    HStack(spacing: 3) {
      if upper.contains("APPLE") {
        Image(systemName: "appletv")
          .font(.system(size: 7))
          .foregroundStyle(Color.white)
      }
      Text(label)
        .font(.system(size: label.count > 8 ? 6.8 : 7.5, weight: .black, design: .rounded))
        .foregroundStyle(Color.white)
        .lineLimit(1)
    }
    .padding(.horizontal, 3)
    .padding(.vertical, 1)
    .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(badgeColor))
  }
}

// MARK: - Empty states

private struct UnconfiguredView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "sportscourt")
        .font(.title2)
        .foregroundStyle(Color.secondary)
      Text("No team selected")
        .font(.headline)
        .foregroundStyle(Color.primary)
      Text("Edit widget to choose a team")
        .font(.caption2)
        .foregroundStyle(Color.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct NoGamesView: View {
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "moon.zzz")
        .font(.title2)
        .foregroundStyle(Color.secondary)
      Text("No games available")
        .font(.headline)
        .foregroundStyle(Color.primary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
