import Foundation
import WidgetKit

@MainActor
final class AppViewModel: ObservableObject {
  @Published private(set) var snapshot: ScheduleSnapshot

  private let repository = ScheduleRepository()
  private var autoRefreshTask: Task<Void, Never>?

  init() {
    snapshot = repository.currentSnapshot()
  }

  deinit {
    autoRefreshTask?.cancel()
  }

  var previousGames: [CapsGame] {
    snapshot.games.previousGames()
  }

  var upcomingGames: [CapsGame] {
    snapshot.games.upcomingGames()
  }

  var hasVisibleGames: Bool {
    !previousGames.isEmpty || !upcomingGames.isEmpty
  }

  var errorMessage: String? {
    snapshot.errorMessage
  }

  var lastUpdatedLabel: String {
    snapshot.lastUpdated.formatted(date: .omitted, time: .shortened)
  }

  var lastUpdated: Date {
    snapshot.lastUpdated
  }

  var teamSummaryLine: String? {
    snapshot.teamSummary?.inlineDisplay
  }

  func loadInitialSnapshotIfNeeded() async {
    startAutoRefreshLoopIfNeeded()
    await refresh()
  }

  func refresh() async {
    snapshot = await repository.refresh()
    WidgetCenter.shared.reloadAllTimelines()
  }

  private func startAutoRefreshLoopIfNeeded() {
    guard autoRefreshTask == nil else {
      return
    }

    autoRefreshTask = Task { [weak self] in
      while !Task.isCancelled {
        guard let self else {
          return
        }

        let intervalSeconds = self.nextRefreshIntervalSeconds()
        let nanoseconds = UInt64(intervalSeconds * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)

        if Task.isCancelled {
          return
        }

        await self.refresh()
      }
    }
  }

  private func nextRefreshIntervalSeconds() -> TimeInterval {
    if snapshot.hasLiveGame {
      return 5 * 60
    }

    if snapshot.errorMessage != nil, snapshot.games.isEmpty {
      return 30 * 60
    }

    return 24 * 60 * 60
  }
}
