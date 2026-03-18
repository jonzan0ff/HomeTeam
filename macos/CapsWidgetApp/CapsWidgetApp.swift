import SwiftUI

@main
struct CapsWidgetApp: App {
  @StateObject private var viewModel = AppViewModel()
  @StateObject private var loginItemManager = LoginItemManager()

  var body: some Scene {
    Window("Washington Capitals", id: "main") {
      ContentView()
        .environmentObject(viewModel)
        .task {
          await viewModel.loadInitialSnapshotIfNeeded()
        }
    }

    Settings {
      Form {
        Toggle("Open at Login", isOn: Binding(
          get: { loginItemManager.openAtLogin },
          set: { value in
            loginItemManager.setOpenAtLogin(value)
          }
        ))

        if let message = loginItemManager.message {
          Text(message)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .padding()
      .frame(width: 360)
    }
  }
}
