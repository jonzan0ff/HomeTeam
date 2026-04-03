import SwiftUI
import AppKit

@main
struct HomeTeamApp: App {

  @StateObject private var settings = AppSettingsStore.shared
  @StateObject private var repository = ScheduleRepository.shared
  @ObservedObject private var appState  = AppState.shared

  init() {
    // Enforce single instance: terminate any older running copy before starting
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
      .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    others.forEach { $0.terminate() }

    // Clear HTTP cache so AsyncImage always fetches fresh logos on launch
    URLCache.shared.removeAllCachedResponses()

    // Refresh on launch + adaptive background schedule (60 s live / 60 min idle)
    Task { ScheduleRepository.shared.startAutoRefresh() }
    // Check for updates on launch + every 24h
    Task { AppState.shared.startDailyUpdateCheck() }
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
