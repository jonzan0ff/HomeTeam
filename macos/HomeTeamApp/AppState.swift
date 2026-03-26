import Foundation
import Combine

// MARK: - Transient app-wide UI state (not persisted)

@MainActor
final class AppState: ObservableObject {
  @Published var isOnboardingPresented = false
  @Published var activeSettingsTab: SettingsTab = .teams

  enum SettingsTab: String, CaseIterable, Identifiable {
    case teams      = "Teams"
    case streaming  = "Streaming"
    case notifications = "Notifications"
    case advanced   = "Advanced"
    var id: String { rawValue }
  }
}
