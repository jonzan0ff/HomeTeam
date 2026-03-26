import SwiftUI

// MARK: - Main menu-bar popover content

struct MenuBarContentView: View {
  @EnvironmentObject var settings: AppSettingsStore
  @EnvironmentObject var repository: ScheduleRepository
  @EnvironmentObject var appState: AppState

  var body: some View {
    VStack(spacing: 0) {
      HeaderView()
      Divider()

      if AppGroupStore.containerURL == nil {
        AppGroupErrorBanner()
      }

      if settings.settings.favoriteTeamCompositeIDs.isEmpty {
        OnboardingPromptView()
      } else {
        GameListView()
      }

      Divider()
      FooterView()
    }
    .frame(width: 360)
    .task {
      // Refresh on popover open only if data is stale (>5 min old)
      if Date().timeIntervalSince(repository.snapshot.fetchedAt) > 300 {
        await repository.refresh()
      }
    }
  }
}

// MARK: - Header

private struct HeaderView: View {
  @EnvironmentObject var repository: ScheduleRepository

  var body: some View {
    HStack {
      Text("HomeTeam")
        .font(.headline)
      Spacer()
      if repository.isRefreshing {
        ProgressView().scaleEffect(0.6)
      } else {
        // Live status dot
        if liveCount > 0 {
          Label("\(liveCount) live", systemImage: "dot.radiowaves.left.and.right")
            .font(.caption)
            .foregroundColor(.green)
        }
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  private var liveCount: Int {
    repository.snapshot.games.filter { $0.status == .live }.count
  }
}

// MARK: - Game list

private struct GameListView: View {
  @EnvironmentObject var repository: ScheduleRepository
  @EnvironmentObject var settings: AppSettingsStore

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(filteredGames) { game in
          GameRowView(game: game)
          Divider().padding(.leading, 12)
        }
      }
    }
    .frame(minHeight: 120, maxHeight: 500)
  }

  private var filteredGames: [HomeTeamGame] {
    menuBarGames(
      from: repository.snapshot.games,
      selectedStreamingKeys: Set(settings.settings.selectedStreamingServices),
      hiddenCompositeIDs: Set(settings.settings.hideDuringOffseasonTeamCompositeIDs)
    )
  }
}

// MARK: - Menu bar game filter (extracted for testability)

/// Returns games visible in the menu bar: only scheduled/live, streaming-filtered, offseason-hidden.
func menuBarGames(
  from games: [HomeTeamGame],
  selectedStreamingKeys: Set<String>,
  hiddenCompositeIDs: Set<String>
) -> [HomeTeamGame] {
  games
    .filter { game in
      // Offseason hide: look up by espnTeamID
      if let team = TeamCatalog.teams(for: game.sport).first(where: { $0.espnTeamID == game.homeTeamID }),
         hiddenCompositeIDs.contains(team.compositeID),
         game.isOffseason { return false }
      return true
    }
    .filter { $0.status == .scheduled || $0.status == .live }
    .sorted { $0.scheduledAt < $1.scheduledAt }
    .filter { game in
      guard !selectedStreamingKeys.isEmpty else { return true }
      let recognisedKeys = game.broadcastNetworks.compactMap { StreamingServiceMatcher.canonicalKey(for: $0) }
      guard !recognisedKeys.isEmpty else { return false }
      return recognisedKeys.allSatisfy { selectedStreamingKeys.contains($0) }
    }
}

// MARK: - Onboarding prompt

private struct OnboardingPromptView: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "star.circle")
        .font(.system(size: 40))
        .foregroundColor(.secondary)
      Text("No teams selected")
        .font(.headline)
      Text("Open Settings to choose your favorite teams.")
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
      SettingsLink {
        Text("Open Settings")
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(24)
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Footer

private struct FooterView: View {
  @EnvironmentObject var repository: ScheduleRepository

  var body: some View {
    HStack {
      if let err = repository.lastError {
        Text("Error: \(err.localizedDescription)")
          .font(.caption2)
          .foregroundColor(.red)
          .lineLimit(1)
      } else if repository.snapshot.fetchedAt != .distantPast {
        Text("Updated \(repository.snapshot.fetchedAt.formatted(.relative(presentation: .named)))")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      if let built = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
        Text("build \(built)")
          .font(.caption2)
          .foregroundColor(.secondary.opacity(0.4))
      }
      Spacer()
      SettingsLink {
        Image(systemName: "gearshape")
      }
      .buttonStyle(.plain)
      .help("Settings")

      Button {
        Task { await repository.refresh() }
      } label: {
        Image(systemName: "arrow.clockwise")
      }
      .buttonStyle(.plain)
      .help("Refresh now")
      .disabled(repository.isRefreshing)

      Button {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
          .forEach { $0.terminate() }
      } label: {
        Image(systemName: "power")
      }
      .buttonStyle(.plain)
      .help("Quit HomeTeam")
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
  }
}

// MARK: - App Group debug banner (shown when container is inaccessible)
private struct AppGroupErrorBanner: View {
  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.yellow)
      Text("App Group not accessible — widget will not update")
        .font(.caption2)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
    .background(Color.yellow.opacity(0.15))
  }
}
