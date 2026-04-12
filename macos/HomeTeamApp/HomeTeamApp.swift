import SwiftUI
import AppKit
import WidgetKit

@main
struct HomeTeamApp: App {

  @ObservedObject private var settings = AppSettingsStore.shared
  @ObservedObject private var repository = ScheduleRepository.shared
  @ObservedObject private var appState  = AppState.shared

  init() {
    // QA Mac data seeding: --import-settings <path> and --import-snapshot <path>
    // Copies the file into the App Group container on launch, then continues normal startup.
    // Used by QA scripts to seed real user data into the installed app for testing.
    Self.handleImportFlags()

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

    // Immediately reload widget timelines so they pick up any data already in the snapshot
    // (e.g. after an auto-update replaced the binary but the widget extension was stale)
    WidgetCenter.shared.reloadAllTimelines()
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

  /// Parses `--import-settings <path>` and `--import-snapshot <path>` from the command line
  /// and copies the named file into the App Group container. Used by QA scripts to seed
  /// real user data into an installed build on the QA Mac.
  ///
  /// Usage: `open /Applications/HomeTeam.app --args --import-settings /tmp/app_settings.json`
  private static func handleImportFlags() {
    let args = CommandLine.arguments
    guard let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.com.hometeam.shared"
    ) else { return }

    func importFile(flag: String, destinationName: String) {
      guard let idx = args.firstIndex(of: flag),
            idx + 1 < args.count else { return }
      let sourcePath = args[idx + 1]
      let sourceURL = URL(fileURLWithPath: sourcePath)
      guard FileManager.default.fileExists(atPath: sourcePath) else {
        print("[import] source not found: \(sourcePath)")
        return
      }
      let destURL = containerURL.appendingPathComponent(destinationName)
      try? FileManager.default.removeItem(at: destURL)
      do {
        try FileManager.default.copyItem(at: sourceURL, to: destURL)
        print("[import] \(destinationName) <- \(sourcePath)")
      } catch {
        print("[import] failed: \(error)")
      }
    }

    importFile(flag: "--import-settings", destinationName: "app_settings.json")
    importFile(flag: "--import-snapshot", destinationName: "schedule_snapshot.json")
  }
}
