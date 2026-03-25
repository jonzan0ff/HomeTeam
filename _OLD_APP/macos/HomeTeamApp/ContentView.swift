import AppKit
import SwiftUI

struct ContentView: View {
  @Environment(\.openSettings) private var openSettings
  @EnvironmentObject private var viewModel: AppViewModel
  @EnvironmentObject private var settingsViewModel: AppSettingsViewModel
  @AppStorage("HomeTeam.didAutoOpenSettingsForOnboarding") private var didAutoOpenSettingsForOnboarding = false

  @State private var hasProcessedLaunchFlow = false
  @State private var emphasizeLastUpdated = false
  @State private var emphasizeTask: Task<Void, Never>?
  @State private var runtimeIssueHovering = false

  private var isUITesting: Bool {
    ProcessInfo.processInfo.arguments.contains("-hometeam_ui_testing")
  }

  private var hideDuringOffseasonTeamCompositeIDs: Set<String> {
    Set(settingsViewModel.settings.hideDuringOffseasonTeamCompositeIDs)
  }

  private var selectedServiceLookup: Set<String> {
    settingsViewModel.settings.selectedServiceLookup
  }

  private var teamSections: [TeamScheduleSection] {
    viewModel.teamSections(
      favoriteTeamCompositeIDs: settingsViewModel.settings.favoriteTeamCompositeIDs,
      hideDuringOffseasonTeamCompositeIDs: hideDuringOffseasonTeamCompositeIDs,
      selectedServiceLookup: selectedServiceLookup
    )
  }

  private var hasVisibleGames: Bool {
    viewModel.hasVisibleGames(
      favoriteTeamCompositeIDs: settingsViewModel.settings.favoriteTeamCompositeIDs,
      hideDuringOffseasonTeamCompositeIDs: hideDuringOffseasonTeamCompositeIDs,
      selectedServiceLookup: selectedServiceLookup
    )
  }

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
        Group {
          if teamSections.isEmpty {
            VStack(spacing: 8) {
              Image(systemName: "star")
                .font(.title2)
                .foregroundStyle(Color.white.opacity(0.68))
              Text("Add favorite teams in Settings")
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
          } else if !hasVisibleGames {
            VStack(spacing: 8) {
              Image(systemName: "tv")
                .font(.title2)
                .foregroundStyle(Color.white.opacity(0.68))
              Text("No games available")
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
                ForEach(teamSections) { section in
                  TeamScoreboardBlock(
                    section: section,
                    selectedServiceLookup: selectedServiceLookup
                  )
                }
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

      runtimeIssueIndicator
        .padding(.trailing, 24)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

      if settingsViewModel.needsOnboarding {
        Color.black.opacity(0.35)
          .ignoresSafeArea()

        HomeTeamOnboardingView(
          onOpenSettingsSection: { section in
            settingsViewModel.requestSettingsSection(section)
            openSettings()
          },
          onRefreshCompletion: {
            settingsViewModel.refreshFromStore()
          }
        )
        .environmentObject(settingsViewModel)
        .accessibilityIdentifier("onboarding.card")
      }
    }
    .frame(minWidth: 560, minHeight: 440)
    .onAppear {
      processLaunchFlowIfNeeded()
    }
    .task(id: settingsViewModel.settings.favoriteTeamCompositeIDs) {
      await viewModel.loadInitialSnapshotsIfNeeded(for: settingsViewModel.settings.favoriteTeamCompositeIDs)
    }
    .onChange(of: viewModel.lastUpdated) { _, _ in
      flashLastUpdated()
    }
    .onDisappear {
      emphasizeTask?.cancel()
    }
    .contextMenu {
      Button("Settings…") {
        openSettings()
      }
    }
    .onChange(of: settingsViewModel.needsOnboarding) { _, _ in
      autoOpenSettingsForOnboardingIfNeeded()
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
          await viewModel.refresh(tracking: settingsViewModel.settings.favoriteTeamCompositeIDs)
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

  private var runtimeIssueIndicator: some View {
    VStack(alignment: .trailing, spacing: 10) {
      if runtimeIssueHovering {
        runtimeIssueHoverCard
      }

      Button(action: copyRuntimeIssueDescription) {
        ZStack(alignment: .topTrailing) {
          runtimeIssueStatusLabel
          runtimeIssueCountBadge
        }
      }
      .buttonStyle(.plain)
      .help("Hover to inspect status. Click to copy details.")
      .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.12)) {
          runtimeIssueHovering = hovering
        }
      }
    }
  }

  private var runtimeIssueStatusLabel: some View {
    Text("Status")
      .font(.caption.weight(.semibold))
      .foregroundStyle(Color.white.opacity(0.96))
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(
        Capsule(style: .continuous)
          .fill(viewModel.hasRuntimeIssues ? Color.black.opacity(0.82) : Color.green.opacity(0.78))
      )
      .overlay(
        Capsule(style: .continuous)
          .stroke(
            viewModel.hasRuntimeIssues ? Color.white.opacity(0.22) : Color.green.opacity(0.85),
            lineWidth: 1
          )
      )
  }

  @ViewBuilder
  private var runtimeIssueCountBadge: some View {
    if viewModel.hasRuntimeIssues {
      Text("\(viewModel.runtimeIssueCount)")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
          Capsule(style: .continuous)
            .fill(Color.red)
        )
        .overlay(
          Capsule(style: .continuous)
            .stroke(Color.white.opacity(0.45), lineWidth: 1)
        )
        .offset(x: 8, y: -8)
    }
  }

  private var runtimeIssueHoverCard: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(viewModel.hasRuntimeIssues ? "Data Issues (\(viewModel.runtimeIssueCount))" : "System Healthy")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.white.opacity(0.95))

      Divider()
        .background(Color.white.opacity(0.22))

      ScrollView {
        Text(viewModel.runtimeIssueDescription)
          .font(.system(size: 12, weight: .regular, design: .rounded))
          .foregroundStyle(Color.white.opacity(0.95))
          .lineSpacing(3)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
      .frame(width: 500, alignment: .topLeading)
      .frame(minHeight: 120, maxHeight: 260, alignment: .topLeading)

      Text("Click Status to copy these details.")
        .font(.caption2)
        .foregroundStyle(Color.white.opacity(0.72))
    }
      .padding(14)
      .frame(width: 520, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(Color.black.opacity(0.9))
          .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .stroke(Color.red.opacity(0.55), lineWidth: 1)
          )
      )
      .offset(x: -10, y: -16)
  }

  private func copyRuntimeIssueDescription() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(viewModel.runtimeIssueDescription, forType: .string)
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

  private func processLaunchFlowIfNeeded() {
    guard !hasProcessedLaunchFlow else {
      return
    }

    hasProcessedLaunchFlow = true

    if ProcessInfo.processInfo.arguments.contains("-hometeam_reset_on_launch") {
      settingsViewModel.resetSetupForOnboarding()
      didAutoOpenSettingsForOnboarding = false
    }

    autoOpenSettingsForOnboardingIfNeeded()
  }

  private func autoOpenSettingsForOnboardingIfNeeded() {
    guard !isUITesting else {
      return
    }

    guard settingsViewModel.needsOnboarding, !didAutoOpenSettingsForOnboarding else {
      return
    }

    settingsViewModel.requestSettingsSection(.favoriteTeams)
    openSettings()
    didAutoOpenSettingsForOnboarding = true
  }

}

private enum ScoreboardRowType {
  case previous
  case upcoming
}

private struct TeamScoreboardBlock: View {
  let section: TeamScheduleSection
  let selectedServiceLookup: Set<String>

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .center, spacing: 8) {
        Text(section.team.displayName)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Color.white.opacity(0.9))
          .lineLimit(1)

        if let summary = section.teamSummaryLine {
          Text(summary)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Color.white.opacity(0.62))
            .lineLimit(1)
        }
      }

      ScoreboardSectionView(
        title: "Previous",
        games: section.previousGames,
        rowType: .previous,
        selectedServiceLookup: selectedServiceLookup
      )
      ScoreboardSectionView(
        title: "Upcoming",
        games: section.upcomingGames,
        rowType: .upcoming,
        selectedServiceLookup: selectedServiceLookup
      )
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.white.opacity(0.04))
        .overlay(
          RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(Color.white.opacity(0.11), lineWidth: 1)
        )
    )
  }
}

private struct ScoreboardSectionView: View {
  let title: String
  let games: [HomeTeamGame]
  let rowType: ScoreboardRowType
  let selectedServiceLookup: Set<String>

  private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption2.weight(.bold))
        .textCase(.uppercase)
        .kerning(1.0)
        .foregroundStyle(Color.white.opacity(0.64))

      if games.isEmpty {
        Text(rowType == .previous ? "No final games yet." : "No upcoming games.")
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
            ScoreboardCardView(
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

private struct ScoreboardCardView: View {
  let game: HomeTeamGame
  let rowType: ScoreboardRowType
  let selectedServiceLookup: Set<String>
  @State private var isCalendarHovering = false

  private var leadingChipText: String {
    game.scoreboardDateLabel
  }

  private var primaryStream: String? {
    game.preferredStreamingService(selectedServiceLookup: selectedServiceLookup)
  }

  private var trailingHeaderText: String {
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

      if showsRacingResults, let lines = game.racingResults {
        RacingResultsListView(lines: lines, sport: game.sport)
      } else if showsRacingUpcomingEventName {
        Text(game.homeTeam)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Color.white.opacity(0.90))
          .lineLimit(2)

        upcomingFooter
      } else {
        VStack(spacing: 5) {
          if !game.awayAbbrev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ScoreboardTeamRow(
              abbrev: game.awayAbbrev,
              logoURL: game.awayLogoURL,
              sport: game.sport,
              isLeader: awayIsLeader,
              trailingValue: trailingValue(
                rowType: rowType,
                score: game.awayScore,
                record: game.awayRecord,
                status: game.status
              )
            )
          }

          if !game.homeAbbrev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ScoreboardTeamRow(
              abbrev: game.homeAbbrev,
              logoURL: game.homeLogoURL,
              sport: game.sport,
              isLeader: homeIsLeader,
              trailingValue: trailingValue(
                rowType: rowType,
                score: game.homeScore,
                record: game.homeRecord,
                status: game.status
              )
            )
          }
        }

        upcomingFooter
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
  
  
  @ViewBuilder
  private var upcomingFooter: some View {
    if rowType == .upcoming {
      HStack {
        StreamBadgeView(service: primaryStream ?? "TV", sport: game.sport)

        Spacer()

        if let calendarURL = game.googleCalendarURL {
          Link(destination: calendarURL) {
            Image(systemName: "calendar")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle(Color.white.opacity(0.92))
              .padding(4)
              .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                  .fill(Color.white.opacity(isCalendarHovering ? 0.24 : 0.10))
              )
              .scaleEffect(isCalendarHovering ? 1.05 : 1.0)
              .animation(.easeInOut(duration: 0.15), value: isCalendarHovering)
          }
          .help("Add to Google Calendar")
          .onHover { hovering in
            isCalendarHovering = hovering
          }
        }
      }
    }
  }

  private func trailingValue(rowType: ScoreboardRowType, score: Int?, record: String?, status: GameStatus) -> String {
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

private struct RacingResultsListView: View {
  let lines: [RacingResultLine]
  let sport: SupportedSport?

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(lines) { line in
        RacingResultRow(line: line, sport: sport)
      }
    }
  }
}

private struct RacingResultRow: View {
  let line: RacingResultLine
  let sport: SupportedSport?

  var body: some View {
    HStack(spacing: 8) {
      Text("\(line.place)")
        .font(.caption.weight(.semibold))
        .frame(width: 16, alignment: .leading)
        .foregroundStyle(Color.white.opacity(0.92))

      TeamIdentityView(abbrev: line.teamAbbrev, logoURL: line.teamLogoURL, sport: sport, isLeader: line.isFavorite)

      Text(line.displayText)
        .font(.caption.weight(line.isFavorite ? .bold : .regular))
        .foregroundStyle(line.isFavorite ? Color.white : Color.white.opacity(0.88))
        .lineLimit(1)
    }
  }
}

private struct ScoreboardTeamRow: View {
  let abbrev: String
  let logoURL: String?
  let sport: SupportedSport?
  let isLeader: Bool
  let trailingValue: String

  var body: some View {
    HStack(spacing: 8) {
      TeamIdentityView(abbrev: abbrev, logoURL: logoURL, sport: sport, isLeader: isLeader)
      Spacer()
      if !trailingValue.isEmpty {
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
}

private struct TeamIdentityView: View {
  private let teamLogoStore = TeamLogoStore()
  let abbrev: String
  let logoURL: String?
  let sport: SupportedSport?
  let isLeader: Bool

  var body: some View {
    HStack(spacing: 7) {
      if let image = teamLogoStore.cachedImage(for: logoURL, teamAbbrev: abbrev, sport: sport) {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
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

  private var color: Color {
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
    if upper.contains("YOUTUBE") {
      return Color(red: 0.86, green: 0.16, blue: 0.16)
    }
    if upper.contains("APPLE") {
      return Color.white.opacity(0.22)
    }
    if upper.contains("NETFLIX") {
      return Color(red: 0.78, green: 0.12, blue: 0.16)
    }
    if upper.contains("HBO") || upper.contains("MAX") {
      return Color(red: 0.45, green: 0.26, blue: 0.85)
    }
    return Color.white.opacity(0.2)
  }

  var body: some View {
    HStack(spacing: 4) {
      if let logo = serviceLogo {
        logo
          .scaledToFit()
          .frame(width: 12, height: 12)
      }

      Text(badgeText)
        .font(.system(size: badgeText.count > 8 ? 7.5 : 8.5, weight: .black, design: .rounded))
        .foregroundStyle(Color.white.opacity(0.96))
        .lineLimit(1)
    }
    .padding(.horizontal, 4)
    .padding(.vertical, 1)
    .background(
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(color)
    )
  }

  private var serviceLogo: AnyView? {
    if normalizedService.contains("APPLE") {
      return AnyView(
        Image(systemName: "applelogo")
          .resizable()
      )
    }

    guard let logoURL = StreamingProviderLogoCatalog.logoURL(for: service) else {
      return nil
    }

    if let image = teamLogoStore.cachedImage(for: logoURL, sport: sport) {
      return AnyView(
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
      )
    }

    return nil
  }
}
