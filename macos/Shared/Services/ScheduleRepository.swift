import Foundation

struct ScheduleRepository {
  private let client = ScheduleClient()
  private let store = SharedScheduleStore()
  private let teamLogoStore = TeamLogoStore()

  func refresh() async -> ScheduleSnapshot {
    do {
      async let gamesTask = client.fetchGames()
      async let summaryTask = client.fetchCapitalsSummary()

      let games = try await gamesTask
      async let logoPrefetchTask: Void = teamLogoStore.prefetchLogos(for: games)
      let teamSummary = await summaryTask
      _ = await logoPrefetchTask

      let snapshot = ScheduleSnapshot(games: games, lastUpdated: Date(), errorMessage: nil, teamSummary: teamSummary)
      try store.save(snapshot)
      return snapshot
    } catch {
      let stale = store.load()
      let reason: String
      if let decodingError = error as? DecodingError {
        reason = "Decoding error: \(Self.describe(decodingError))"
      } else {
        reason = error.localizedDescription
      }

      return ScheduleSnapshot(
        games: stale?.games ?? [],
        lastUpdated: stale?.lastUpdated ?? Date(),
        errorMessage: "Refresh failed (\(reason)). Showing last available data.",
        teamSummary: stale?.teamSummary
      )
    }
  }

  func currentSnapshot() -> ScheduleSnapshot {
    store.load() ?? ScheduleSnapshot(games: [], lastUpdated: Date(), errorMessage: "No data yet", teamSummary: nil)
  }

  private static func describe(_ error: DecodingError) -> String {
    switch error {
    case .typeMismatch(_, let context):
      return "typeMismatch at \(codingPath(context.codingPath)): \(context.debugDescription)"
    case .valueNotFound(_, let context):
      return "valueNotFound at \(codingPath(context.codingPath)): \(context.debugDescription)"
    case .keyNotFound(let key, let context):
      return "keyNotFound '\(key.stringValue)' at \(codingPath(context.codingPath)): \(context.debugDescription)"
    case .dataCorrupted(let context):
      return "dataCorrupted at \(codingPath(context.codingPath)): \(context.debugDescription)"
    @unknown default:
      return "unknown decoding error"
    }
  }

  private static func codingPath(_ path: [CodingKey]) -> String {
    if path.isEmpty {
      return "$"
    }

    return "$." + path.map { key in
      if let intValue = key.intValue {
        return "[\(intValue)]"
      }
      return key.stringValue
    }.joined(separator: ".")
  }
}
