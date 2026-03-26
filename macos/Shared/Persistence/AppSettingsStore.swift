import Foundation
import Combine

// MARK: - AppSettings persistence (App Group JSON only)
// iCloud KV sync intentionally omitted until ubiquity-kvstore-identifier
// entitlement is fully provisioned. App Group JSON is the source of truth
// shared with the widget.

final class AppSettingsStore: ObservableObject {
  static let shared = AppSettingsStore()

  @Published private(set) var settings: AppSettings = .default

  private init() { load() }

  func update(_ block: (inout AppSettings) -> Void) {
    var copy = settings
    block(&copy)
    settings = copy
    do {
      try AppGroupStore.write(settings, to: AppGroupStore.settingsFilename)
    } catch {
      print("[AppSettingsStore] ❌ write failed: \(error)")
    }
  }

  private func load() {
    if let decoded = try? AppGroupStore.read(AppSettings.self, from: AppGroupStore.settingsFilename) {
      settings = decoded
    }
  }
}
