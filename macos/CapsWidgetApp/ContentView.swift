import SwiftUI
import AppKit

struct ContentView: View {
  @EnvironmentObject private var viewModel: AppViewModel
  @State private var emphasizeLastUpdated = false
  @State private var emphasizeTask: Task<Void, Never>?

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [Color(red: 0.05, green: 0.07, blue: 0.12), Color(red: 0.03, green: 0.04, blue: 0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      RadialGradient(
        colors: [Color(red: 0.74, green: 0.16, blue: 0.16, opacity: 0.22), .clear],
        center: .topLeading,
        startRadius: 20,
        endRadius: 420
      )
      .ignoresSafeArea()

      VStack(spacing: 12) {
        header

        if let error = viewModel.errorMessage {
          Text(error)
            .font(.caption)
            .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.62))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.18))
            )
        }
        Group {
          if !viewModel.hasVisibleGames {
            VStack(spacing: 8) {
              Image(systemName: "tv")
                .font(.title2)
                .foregroundStyle(Color.white.opacity(0.68))
              Text("No streamable games")
                .font(.headline)
                .foregroundStyle(Color.white.opacity(0.86))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
              RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                  RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
            )
          } else {
            ScrollView {
              VStack(spacing: 14) {
                ScoreboardSectionView(title: "Previous", games: viewModel.previousGames, rowType: .previous)
                ScoreboardSectionView(title: "Upcoming", games: viewModel.upcomingGames, rowType: .upcoming)
              }
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 2)
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        footer
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .fill(Color.white.opacity(0.08))
          .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
              .stroke(Color.white.opacity(0.14), lineWidth: 1)
          )
      )
      .padding(16)
    }
    .frame(minWidth: 560, minHeight: 440)
    .onChange(of: viewModel.lastUpdated) { _ in
      flashLastUpdated()
    }
    .onDisappear {
      emphasizeTask?.cancel()
    }
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 10) {
      if let summary = viewModel.teamSummaryLine {
        Text(summary)
          .font(.caption2.weight(.medium))
          .foregroundStyle(Color.white.opacity(0.66))
          .lineLimit(1)
      }

      Spacer()
    }
  }

  private var footer: some View {
    HStack(spacing: 8) {
      Text("Updated \(viewModel.lastUpdatedLabel)")
        .font(.caption)
        .fontWeight(emphasizeLastUpdated ? .bold : .regular)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .truncationMode(.tail)
        .foregroundStyle(emphasizeLastUpdated ? Color.white : Color.white.opacity(0.70))
        .animation(.easeInOut(duration: 0.18), value: emphasizeLastUpdated)

      Button {
        Task {
          await viewModel.refresh()
        }
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(Color.white.opacity(0.9))
          .frame(width: 20, height: 20)
          .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
              .fill(Color.white.opacity(0.12))
          )
      }
      .buttonStyle(.plain)
      .help("Refresh now")

      Spacer()
    }
  }

  private func flashLastUpdated() {
    emphasizeTask?.cancel()
    emphasizeTask = Task {
      await MainActor.run {
        emphasizeLastUpdated = true
      }

      try? await Task.sleep(nanoseconds: 900_000_000)

      if Task.isCancelled {
        return
      }

      await MainActor.run {
        emphasizeLastUpdated = false
      }
    }
  }
}

private enum ScoreboardRowType {
  case previous
  case upcoming
}

private struct ScoreboardSectionView: View {
  let title: String
  let games: [CapsGame]
  let rowType: ScoreboardRowType

  private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption2.weight(.bold))
        .textCase(.uppercase)
        .kerning(1.0)
        .foregroundStyle(Color.white.opacity(0.64))

      if games.isEmpty {
        Text(rowType == .previous ? "No final games yet." : "No upcoming streamable games.")
          .font(.caption)
          .foregroundStyle(Color.white.opacity(0.68))
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(Color.white.opacity(0.05))
          )
      } else {
        LazyVGrid(columns: columns, spacing: 10) {
          ForEach(games) { game in
            ScoreboardCardView(game: game, rowType: rowType)
          }
        }
      }
    }
  }
}

private struct ScoreboardCardView: View {
  let game: CapsGame
  let rowType: ScoreboardRowType

  private var leadingChipText: String {
    game.scoreboardDateLabel
  }

  private var primaryStream: String? {
    game.streamingServices.first
  }

  private var trailingHeaderText: String {
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
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 6) {
        Text(leadingChipText)
          .font(.caption2.weight(.bold))
          .textCase(.uppercase)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .truncationMode(.tail)
          .padding(.horizontal, 7)
          .padding(.vertical, 2)
          .background(
            Capsule(style: .continuous)
              .fill(Color.white.opacity(0.14))
          )
          .foregroundStyle(Color.white.opacity(0.84))

        Spacer()

        Text(trailingHeaderText)
          .font(.caption2)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .truncationMode(.tail)
          .foregroundStyle(Color.white.opacity(0.68))
      }

      VStack(spacing: 5) {
        ScoreboardTeamRow(
          abbrev: game.awayAbbrev,
          logoURL: game.awayLogoURL,
          isLeader: awayIsLeader,
          trailingValue: trailingValue(
            rowType: rowType,
            score: game.awayScore,
            record: game.awayRecord,
            status: game.status
          )
        )

        ScoreboardTeamRow(
          abbrev: game.homeAbbrev,
          logoURL: game.homeLogoURL,
          isLeader: homeIsLeader,
          trailingValue: trailingValue(
            rowType: rowType,
            score: game.homeScore,
            record: game.homeRecord,
            status: game.status
          )
        )
      }

      if rowType == .upcoming {
        HStack {
          if let primaryStream {
            StreamBadgeView(service: primaryStream)
          }

          Spacer()

          if let calendarURL = game.googleCalendarURL {
            Link(destination: calendarURL) {
              Image(systemName: "calendar")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            }
          }
        }
      }
    }
    .padding(7)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(
          LinearGradient(
            colors: [Color.white.opacity(0.10), Color.white.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .stroke(game.status == .live ? Color.red.opacity(0.55) : Color.white.opacity(0.16), lineWidth: 1)
    )
  }

  private func trailingValue(rowType: ScoreboardRowType, score: Int?, record: String?, status: GameStatus) -> String {
    if rowType == .previous || status != .scheduled {
      return "\(score ?? 0)"
    }

    return record ?? "-"
  }
}

private struct ScoreboardTeamRow: View {
  let abbrev: String
  let logoURL: String?
  let isLeader: Bool
  let trailingValue: String

  var body: some View {
    HStack(spacing: 8) {
      TeamIdentityView(abbrev: abbrev, logoURL: logoURL, isLeader: isLeader)
      Spacer()
      HStack(spacing: 3) {
        Text(trailingValue)
          .font(.caption.weight(isLeader ? .bold : .regular))
          .foregroundStyle(isLeader ? Color.white : Color.white.opacity(0.88))
          .monospacedDigit()
        Image(systemName: "arrowtriangle.left.fill")
          .font(.system(size: 6, weight: .bold))
          .foregroundStyle(Color.white.opacity(isLeader ? 0.9 : 0.0))
          .frame(width: 5, alignment: .center)
      }
    }
  }
}

private struct TeamIdentityView: View {
  private let teamLogoStore = TeamLogoStore()
  let abbrev: String
  let logoURL: String?
  let isLeader: Bool

  var body: some View {
    HStack(spacing: 7) {
      if let image = teamLogoStore.cachedImage(for: logoURL, teamAbbrev: abbrev) {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
          .frame(width: 16, height: 16)
      } else if let logoURL, let remoteURL = URL(string: logoURL) {
        AsyncImage(url: remoteURL) { phase in
          if let image = phase.image {
            image
              .resizable()
              .scaledToFit()
          } else {
            Text(shortAbbrev)
              .font(.caption2.weight(.bold))
              .foregroundStyle(Color.white.opacity(0.88))
          }
        }
        .frame(width: 16, height: 16)
      } else {
        Text(shortAbbrev)
          .font(.caption2.weight(.bold))
          .foregroundStyle(Color.white.opacity(0.88))
          .frame(width: 16, height: 16)
      }

      Text(shortAbbrev)
        .font(.caption.weight(isLeader ? .bold : .regular))
        .foregroundStyle(isLeader ? Color.white : Color.white.opacity(0.88))
        .frame(minWidth: 26, alignment: .leading)
    }
  }

  private var shortAbbrev: String {
    String(abbrev.prefix(3)).uppercased()
  }
}

private struct StreamBadgeView: View {
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
    let upper = normalizedService
    if upper.contains("APPLE") {
      return "apple.logo"
    }
    if upper.contains("NETFLIX") {
      return "play.rectangle.fill"
    }
    if upper.contains("AMAZON") || upper.contains("PRIME") {
      return "cart.fill"
    }
    if upper.contains("HULU") {
      return "play.tv.fill"
    }
    if upper.contains("ESPN") {
      return "sportscourt.fill"
    }
    if upper.contains("PEACOCK") {
      return "dot.radiowaves.left.and.right"
    }
    if upper.contains("HBO") || upper.contains("MAX") {
      return "film.fill"
    }
    if upper.contains("PARAMOUNT") {
      return "play.tv.fill"
    }
    return "tv.fill"
  }

  private var color: Color {
    let upper = normalizedService
    if upper.contains("NETFLIX") {
      return Color(red: 0.78, green: 0.12, blue: 0.16)
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
    if upper.contains("PARAMOUNT") {
      return Color(red: 0.10, green: 0.40, blue: 0.85)
    }
    return Color.white.opacity(0.2)
  }

  var body: some View {
    Group {
      if isHBO {
        Text("HBO")
          .font(.system(size: 10, weight: .black, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.95))
      } else if isHulu {
        Text("HULU")
          .font(.system(size: 8.5, weight: .black, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.96))
          .padding(.horizontal, 4)
          .padding(.vertical, 1)
          .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .fill(Color(red: 0.09, green: 0.74, blue: 0.46))
          )
      } else {
        Image(systemName: symbolName)
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(Color.white.opacity(0.95))
          .frame(width: 18, height: 13)
          .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .fill(color)
          )
      }
    }
  }
}
