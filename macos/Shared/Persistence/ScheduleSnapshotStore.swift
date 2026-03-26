import Foundation
import Combine

// MARK: - ScheduleSnapshot persistence (App Group only; no iCloud sync — too large)

final class ScheduleSnapshotStore: ObservableObject {
  static let shared = ScheduleSnapshotStore()

  @Published private(set) var snapshot: ScheduleSnapshot = .empty

  private let decoder = JSONDecoder()

  private init() {
    load()
  }

  // MARK: Public

  func save(_ snapshot: ScheduleSnapshot) {
    self.snapshot = snapshot
    try? AppGroupStore.write(snapshot, to: AppGroupStore.snapshotFilename)
  }

  func load() {
    if let loaded = try? AppGroupStore.read(ScheduleSnapshot.self, from: AppGroupStore.snapshotFilename) {
      snapshot = loaded
    }
  }
}

extension ScheduleSnapshot {
  static let empty = ScheduleSnapshot(games: [], fetchedAt: .distantPast)
}
