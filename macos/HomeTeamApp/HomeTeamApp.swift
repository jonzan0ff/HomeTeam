import SwiftUI

@main
struct HomeTeamApp: App {
  @StateObject private var viewModel: AppViewModel
  @StateObject private var settingsViewModel: AppSettingsViewModel
  @StateObject private var loginItemManager: LoginItemManager

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    let isUITesting = arguments.contains("-hometeam_ui_testing")

    if isUITesting {
      let settingsDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("HomeTeam-UITests", isDirectory: true)
      let uiTestStore = AppSettingsStore(
        customDirectoryURL: settingsDirectory,
        cloudSyncEnabled: false
      )

      _viewModel = StateObject(
        wrappedValue: AppViewModel(
          networkRefreshEnabled: false,
          widgetReloadEnabled: false
        )
      )
      _settingsViewModel = StateObject(
        wrappedValue: AppSettingsViewModel(
          store: uiTestStore,
          widgetReloadEnabled: false
        )
      )
      _loginItemManager = StateObject(wrappedValue: LoginItemManager())
      return
    }

    _viewModel = StateObject(wrappedValue: AppViewModel())
    _settingsViewModel = StateObject(wrappedValue: AppSettingsViewModel())
    _loginItemManager = StateObject(wrappedValue: LoginItemManager())
  }

  var body: some Scene {
    Window("HomeTeam", id: "main") {
      ContentView()
        .environmentObject(viewModel)
        .environmentObject(settingsViewModel)
    }

    Settings {
      HomeTeamSettingsView()
        .environmentObject(settingsViewModel)
        .environmentObject(loginItemManager)
    }
  }
}
