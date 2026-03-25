import Foundation
import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
  @Published private(set) var openAtLogin: Bool = false
  @Published private(set) var message: String?

  init() {
    refreshStatus()
  }

  func setOpenAtLogin(_ enabled: Bool) {
    guard #available(macOS 13.0, *) else {
      message = "Open at Login requires macOS 13 or later."
      openAtLogin = false
      return
    }

    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      message = nil
    } catch {
      message = "Could not update login setting. You may need to move the app to /Applications and run a signed build."
    }

    refreshStatus()
  }

  private func refreshStatus() {
    guard #available(macOS 13.0, *) else {
      openAtLogin = false
      return
    }

    let status = SMAppService.mainApp.status
    openAtLogin = (status == .enabled)
  }
}
