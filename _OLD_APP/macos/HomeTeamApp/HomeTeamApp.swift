import SwiftUI

@main
struct HomeTeamApp: App {
  @StateObject private var viewModel: AppViewModel
  @StateObject private var settingsViewModel: AppSettingsViewModel
  @StateObject private var loginItemManager: LoginItemManager

  init() {
    let arguments = ProcessInfo.processInfo.arguments
    let isUITesting = arguments.contains("-hometeam_ui_testing")
    let useRealAppGroupInUITest = arguments.contains("-hometeam_real_app_group")

    if isUITesting && useRealAppGroupInUITest {
      let store = AppSettingsStore(cloudSyncEnabled: false)
      _viewModel = StateObject(
        wrappedValue: AppViewModel(
          networkRefreshEnabled: false,
          widgetReloadEnabled: true
        )
      )
      _settingsViewModel = StateObject(
        wrappedValue: AppSettingsViewModel(
          store: store,
          widgetReloadEnabled: true
        )
      )
      _loginItemManager = StateObject(wrappedValue: LoginItemManager())
      return
    }

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
    .commands {
      CommandGroup(replacing: .appInfo) {
        Button("About HomeTeam") {
          HomeTeamMenuAbout.presentStandardPanel()
        }
      }
    }

    Settings {
      HomeTeamSettingsView()
        .environmentObject(settingsViewModel)
        .environmentObject(loginItemManager)
    }
  }
}
