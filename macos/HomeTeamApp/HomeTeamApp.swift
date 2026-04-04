import SwiftUI
import AppKit

@main
struct HomeTeamApp: App {

  @ObservedObject private var settings = AppSettingsStore.shared
  @ObservedObject private var repository = ScheduleRepository.shared
  @ObservedObject private var appState  = AppState.shared

  init() {
    // Enforce single instance: terminate any older running copy and wait for exit
    let bundleID = Bundle.main.bundleIdentifier ?? ""
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
      .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    if !others.isEmpty {
      others.forEach { $0.forceTerminate() }
      Thread.sleep(forTimeInterval: 0.5)
    }

    // Clear HTTP cache so AsyncImage always fetches fresh logos on launch
    URLCache.shared.removeAllCachedResponses()

    // Refresh on launch + adaptive background schedule (60 s live / 60 min idle)
    Task { ScheduleRepository.shared.startAutoRefresh() }
    // Check for updates on launch + every 24h
    Task { AppState.shared.startDailyUpdateCheck() }
    // Install AppKit menu bar item (NSStatusItem + NSPopover)
    MenuBarController.shared.install()
  }

  var body: some Scene {
    Settings {
      HomeTeamSettingsView()
        .environmentObject(settings)
        .environmentObject(repository)
        .environmentObject(appState)
        .frame(width: 520, height: 480)
    }
  }
}
