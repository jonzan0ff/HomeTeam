import SwiftUI
import AppKit

@main
struct HomeTeamApp: App {

  @StateObject private var settings = AppSettingsStore.shared
  @StateObject private var repository = ScheduleRepository.shared
  @StateObject private var appState  = AppState()

  init() {
    // Enforce single instance: terminate any older running copy before starting
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
      .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    others.forEach { $0.terminate() }

    // Clear HTTP cache so AsyncImage always fetches fresh logos on launch
    URLCache.shared.removeAllCachedResponses()

    // Refresh on launch + adaptive background schedule (60 s live / 60 min idle)
    Task { await ScheduleRepository.shared.startAutoRefresh() }
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarContentView()
        .environmentObject(settings)
        .environmentObject(repository)
        .environmentObject(appState)
        .onReceive(settings.$settings.map(\.favoriteTeamCompositeIDs).removeDuplicates().dropFirst()) { favs in
          guard !favs.isEmpty else { return }
          Task { await repository.refresh() }
        }
    } label: {
      MenuBarIcon()
        .environmentObject(repository)
    }
    .menuBarExtraStyle(.window)

    Settings {
      HomeTeamSettingsView()
        .environmentObject(settings)
        .environmentObject(repository)
        .environmentObject(appState)
        .frame(width: 520, height: 480)
    }
  }
}
