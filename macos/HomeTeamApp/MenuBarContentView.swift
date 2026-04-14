import AppKit
import SwiftUI

// MARK: - Main menu-bar popover content (rev 2)
//
// Layout:
//   Header:  HomeTeam vX.Y.Z                     [• N live]
//   Divider
//   Body:    [↻] Refresh
//            [⬇] Check for Updates / Install Update / Installing…
//            [⚙] Settings
//   Divider
//   Footer:  Last updated X ago                  Quit
//
// The games list lives in the widget, not the popover.

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

      VStack(spacing: 0) {
        RefreshRow()
        UpdateRow()
        SettingsRow()
      }
      .padding(.vertical, 4)

      Divider()
      FooterView()
    }
    .frame(width: 320)
  }
}

// MARK: - Header

private struct HeaderView: View {
  @EnvironmentObject var repository: ScheduleRepository

  private var versionString: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
  }

  private var liveCount: Int {
    repository.snapshot.games.filter { $0.status == .live }.count
  }

  var body: some View {
    HStack(spacing: 6) {
      Text("HomeTeam")
        .font(.system(size: 14, weight: .semibold))
      Text("v\(versionString)")
        .font(.system(size: 11, design: .default))
        .monospacedDigit()
        .foregroundColor(.secondary)
      Spacer()
      StatusBadge(liveCount: liveCount)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}

private struct StatusBadge: View {
  let liveCount: Int

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(liveCount > 0 ? Color.green : Color.secondary)
        .frame(width: 6, height: 6)
      Text(liveCount > 0 ? "\(liveCount) live" : "No live games")
        .font(.system(size: 11))
        .foregroundColor(.secondary)
    }
  }
}

// MARK: - Action rows

private struct ActionRow<Trailing: View>: View {
  let icon: String
  let title: String
  var isDisabled: Bool = false
  let action: () -> Void
  @ViewBuilder var trailing: () -> Trailing

  @State private var isHovering = false

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: icon)
          .font(.system(size: 13))
          .frame(width: 18, alignment: .center)
          .foregroundColor(.primary)
        Text(title)
          .font(.system(size: 13))
          .foregroundColor(.primary)
        Spacer()
        trailing()
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
      .contentShape(Rectangle())
      .background(
        (isHovering && !isDisabled)
          ? Color.primary.opacity(0.08)
          : Color.clear
      )
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
    .onHover { isHovering = $0 }
  }
}

private struct RefreshRow: View {
  @EnvironmentObject var repository: ScheduleRepository

  var body: some View {
    ActionRow(
      icon: "arrow.clockwise",
      title: "Refresh",
      isDisabled: repository.isRefreshing,
      action: { Task { await repository.refresh() } },
      trailing: {
        if repository.isRefreshing {
          ProgressView().scaleEffect(0.5).frame(width: 14, height: 14)
        }
      }
    )
  }
}

private struct UpdateRow: View {
  @EnvironmentObject var appState: AppState

  var body: some View {
    if appState.isInstallingUpdate {
      HStack(spacing: 10) {
        ProgressView().scaleEffect(0.5).frame(width: 18, height: 18)
        Text("Installing update…")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
        Spacer()
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
    } else {
      ActionRow(
        icon: "arrow.down.circle",
        title: appState.availableUpdate != nil ? "Install Update" : "Check for Updates",
        action: {
          if appState.availableUpdate != nil {
            appState.installUpdate()
          } else {
            Task { await appState.checkForUpdate() }
          }
        },
        trailing: {
          if appState.availableUpdate != nil {
            Circle().fill(Color.orange).frame(width: 6, height: 6)
          }
        }
      )
    }
  }
}

private struct SettingsRow: View {
  var body: some View {
    ActionRow(
      icon: "gearshape",
      title: "Settings",
      action: {
        // Dismiss popover (NSPopover is transient — sending any action to nil
        // while the popover is key will close it). Then open Settings.
        NSApp.keyWindow?.performClose(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
      },
      trailing: { EmptyView() }
    )
  }
}

// MARK: - Footer

private struct FooterView: View {
  @EnvironmentObject var repository: ScheduleRepository

  var body: some View {
    HStack {
      if repository.snapshot.fetchedAt != .distantPast {
        Text("Last updated \(repository.snapshot.fetchedAt.formatted(.relative(presentation: .named)))")
          .font(.system(size: 11))
          .foregroundColor(Color.secondary.opacity(0.75))
      }
      Spacer()
      QuitButton()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }
}

private struct QuitButton: View {
  @State private var isHovering = false

  var body: some View {
    Button {
      let bundleID = Bundle.main.bundleIdentifier ?? ""
      NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        .forEach { $0.terminate() }
    } label: {
      Text("Quit")
        .font(.system(size: 13))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isHovering ? Color.primary.opacity(0.08) : Color.clear)
        .cornerRadius(4)
    }
    .buttonStyle(.plain)
    .keyboardShortcut("q", modifiers: .command)
    .onHover { isHovering = $0 }
  }
}

// MARK: - Menu bar game filter (retained — referenced by StreamingFilterTests)

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
