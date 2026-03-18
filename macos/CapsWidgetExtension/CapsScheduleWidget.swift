import SwiftUI
import WidgetKit
import AppKit

struct CapsEntry: TimelineEntry {
  let date: Date
  let snapshot: ScheduleSnapshot
}

struct CapsProvider: TimelineProvider {
  private let repository = ScheduleRepository()

  func placeholder(in context: Context) -> CapsEntry {
    CapsEntry(
      date: Date(),
      snapshot: ScheduleSnapshot(games: [], lastUpdated: Date(), errorMessage: nil, teamSummary: nil)
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (CapsEntry) -> Void) {
    Task {
      let snapshot = await repository.refresh()
      completion(CapsEntry(date: Date(), snapshot: snapshot))
    }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CapsEntry>) -> Void) {
    Task {
      let snapshot = await repository.refresh()
      let now = Date()
      let refreshDate = nextRefreshDate(from: snapshot, now: now)
      let entry = CapsEntry(date: now, snapshot: snapshot)
      completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
  }

  private func nextRefreshDate(from snapshot: ScheduleSnapshot, now: Date) -> Date {
    if snapshot.hasLiveGame {
      return now.addingTimeInterval(5 * 60)
    }

    return now.addingTimeInterval(24 * 60 * 60)
  }
}

struct CapsScheduleWidget: Widget {
  let kind: String = "CapsScheduleWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CapsProvider()) { entry in
      CapsScheduleWidgetView(entry: entry)
    }
    .configurationDisplayName("Washington Capitals")
    .description("Washington Capitals next streamable games")
    .supportedFamilies([.systemLarge])
    .containerBackgroundRemovable(false)
  }
}

private struct CapsScheduleWidgetView: View {
  let entry: CapsEntry

  private var previousGames: [CapsGame] {
    entry.snapshot.games.previousGames(now: entry.date, limit: 3)
  }

  private var upcomingGames: [CapsGame] {
    entry.snapshot.games.upcomingGames(now: entry.date, limit: 3)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let summary = entry.snapshot.teamSummary?.inlineDisplay {
        Text(summary)
          .font(.caption2.weight(.medium))
          .foregroundStyle(.white.opacity(0.66))
          .lineLimit(1)
      }

      if previousGames.isEmpty && upcomingGames.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("No streamable games")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))

          Text("Open the app to refresh.")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.62))
        }
      } else {
        WidgetSectionRow(title: "Previous", games: previousGames, rowType: .previous)
        WidgetSectionRow(title: "Upcoming", games: upcomingGames, rowType: .upcoming)
      }

      Spacer(minLength: 0)

      HStack {
        Spacer()
        Text("Updated \(entry.snapshot.lastUpdated.formatted(date: .omitted, time: .shortened))")
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .truncationMode(.tail)
          .foregroundStyle(.white.opacity(0.72))
      }
    }
    .padding(8)
    .containerBackground(
      LinearGradient(
        colors: [
          Color(red: 0.05, green: 0.07, blue: 0.12),
          Color(red: 0.03, green: 0.04, blue: 0.08),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      for: .widget
    )
  }
}

private enum WidgetRowType {
  case previous
  case upcoming
}

private struct WidgetSectionRow: View {
  let title: String
  let games: [CapsGame]
  let rowType: WidgetRowType

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption2.weight(.bold))
        .textCase(.uppercase)
        .foregroundStyle(.white.opacity(0.62))

      if games.isEmpty {
        Text(rowType == .previous ? "No finals" : "No upcoming")
          .font(.caption2)
          .foregroundStyle(.white.opacity(0.54))
      } else {
        HStack(spacing: 6) {
          ForEach(games.prefix(3)) { game in
            WidgetGameCard(game: game, rowType: rowType)
          }
        }
      }
    }
  }
}

private struct WidgetGameCard: View {
  let game: CapsGame
  let rowType: WidgetRowType

  private var leadingChipLabel: String {
    game.widgetDateChipLabel
  }

  private var primaryService: String {
    game.streamingServices.first ?? "Stream"
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
      return "Final"
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

      VStack(spacing: 4) {
        CompactTeamRow(abbrev: game.awayAbbrev, logoURL: game.awayLogoURL, isLeader: awayIsLeader, trailingValue: trailingValueAway)
        CompactTeamRow(abbrev: game.homeAbbrev, logoURL: game.homeLogoURL, isLeader: homeIsLeader, trailingValue: trailingValueHome)
      }

      if rowType == .upcoming {
        HStack(spacing: 6) {
          ServiceLogoView(service: primaryService)
        }
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

  private func trailingValue(score: Int?, record: String?, status: GameStatus) -> String {
    if rowType == .previous || status != .scheduled {
      return "\(score ?? 0)"
    }

    return record ?? "-"
  }
}

private struct CompactTeamRow: View {
  let abbrev: String
  let logoURL: String?
  let isLeader: Bool
  let trailingValue: String

  var body: some View {
    HStack(spacing: 5) {
      TeamMarkView(abbrev: abbrev, logoURL: logoURL, isLeader: isLeader)
      Spacer(minLength: 2)
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

private struct TeamMarkView: View {
  private let teamLogoStore = TeamLogoStore()
  let abbrev: String
  let logoURL: String?
  let isLeader: Bool

  private var shortAbbrev: String {
    String(abbrev.prefix(3)).uppercased()
  }

  var body: some View {
    HStack(spacing: 3) {
      if let image = teamLogoStore.cachedImage(for: logoURL, teamAbbrev: abbrev) {
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
  let service: String

  private var normalizedService: String {
    service.uppercased()
  }

  private var isHBO: Bool {
    normalizedService.contains("HBO") || normalizedService.contains("MAX")
  }

  private var isHulu: Bool {
    normalizedService.contains("HULU")
  }

  private var symbolName: String {
    let uppercase = normalizedService

    if uppercase.contains("APPLE") {
      return "apple.logo"
    }
    if uppercase.contains("NETFLIX") {
      return "play.rectangle.fill"
    }
    if uppercase.contains("AMAZON") || uppercase.contains("PRIME") {
      return "cart.fill"
    }
    if uppercase.contains("HULU") {
      return "play.tv.fill"
    }
    if uppercase.contains("ESPN") {
      return "sportscourt.fill"
    }
    if uppercase.contains("PEACOCK") {
      return "dot.radiowaves.left.and.right"
    }
    if uppercase.contains("HBO") || uppercase.contains("MAX") {
      return "film.fill"
    }
    if uppercase.contains("PARAMOUNT") {
      return "play.tv.fill"
    }

    return "tv.fill"
  }

  private var backgroundColor: Color {
    let uppercase = normalizedService

    if uppercase.contains("APPLE") {
      return Color.white.opacity(0.18)
    }
    if uppercase.contains("NETFLIX") {
      return Color(red: 0.78, green: 0.12, blue: 0.16)
    }
    if uppercase.contains("AMAZON") || uppercase.contains("PRIME") {
      return Color(red: 0.12, green: 0.46, blue: 0.82)
    }
    if uppercase.contains("PEACOCK") {
      return Color(red: 0.95, green: 0.58, blue: 0.10)
    }
    if uppercase.contains("HBO") || uppercase.contains("MAX") {
      return Color(red: 0.45, green: 0.26, blue: 0.85)
    }
    if uppercase.contains("PARAMOUNT") {
      return Color(red: 0.10, green: 0.40, blue: 0.85)
    }

    return Color.white.opacity(0.2)
  }

  var body: some View {
    Group {
      if isHBO {
        Text("HBO")
          .font(.system(size: 8.5, weight: .black, design: .rounded))
          .foregroundStyle(.white.opacity(0.95))
      } else if isHulu {
        Text("HULU")
          .font(.system(size: 7.5, weight: .black, design: .rounded))
          .foregroundStyle(.white.opacity(0.96))
          .padding(.horizontal, 3)
          .padding(.vertical, 1)
          .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .fill(Color(red: 0.09, green: 0.74, blue: 0.46))
          )
      } else {
        Image(systemName: symbolName)
          .font(.system(size: 8.5, weight: .semibold))
          .foregroundStyle(.white.opacity(0.95))
          .frame(width: 16, height: 12)
          .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .fill(backgroundColor)
          )
      }
    }
  }
}
