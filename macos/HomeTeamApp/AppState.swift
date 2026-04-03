import Foundation
import Combine

// MARK: - Transient app-wide UI state (not persisted)

@MainActor
final class AppState: ObservableObject {
  static let shared = AppState()

  @Published var isOnboardingPresented = false
  @Published var activeSettingsTab: SettingsTab = .teams

  // Update state
  @Published var availableUpdate: GitHubRelease?
  @Published var isInstallingUpdate = false
  @Published var updateProgress: Double = 0

  enum SettingsTab: String, CaseIterable, Identifiable {
    case teams      = "Teams"
    case streaming  = "Streaming"
    case notifications = "Notifications"
    case advanced   = "Advanced"
    case about      = "About"
    var id: String { rawValue }
  }

  // MARK: - Update actions

  private var dailyCheckTask: Task<Void, Never>?

  func startDailyUpdateCheck() {
    guard dailyCheckTask == nil else { return }
    dailyCheckTask = Task {
      await checkForUpdate()
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(86400)) // 24 hours
        await checkForUpdate()
      }
    }
  }

  func checkForUpdate() async {
    let release = await UpdateService.shared.checkForUpdate()
    availableUpdate = release
  }

  func installUpdate() {
    guard let release = availableUpdate else { return }
    isInstallingUpdate = true
    updateProgress = 0
    Task {
      do {
        try await UpdateService.shared.downloadAndInstall(release: release) { [weak self] progress in
          Task { @MainActor in self?.updateProgress = progress }
        }
      } catch {
        print("[UpdateService] install failed: \(error)")
        isInstallingUpdate = false
        updateProgress = 0
      }
    }
  }
}
