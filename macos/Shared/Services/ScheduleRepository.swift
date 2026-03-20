import Foundation
import WidgetKit

enum RuntimeIssueCenter {
  static let didChangeNotification = Notification.Name("HomeTeamRuntimeIssuesDidChange")

  private static let queue = DispatchQueue(label: "com.jonzanoff.hometeam.runtime-issues")
  private static var messagesByText: [String: Date] = [:]

  static func report(_ message: String) {
    let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return
    }

    var shouldPost = false
    queue.sync {
      let wasKnown = messagesByText[trimmed] != nil
      messagesByText[trimmed] = Date()
      shouldPost = !wasKnown
    }

    if shouldPost {
      NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
  }

  static func clear() {
    var shouldPost = false
    queue.sync {
      shouldPost = !messagesByText.isEmpty
      messagesByText.removeAll()
    }

    if shouldPost {
      NotificationCenter.default.post(name: didChangeNotification, object: nil)
    }
  }

  static func allMessages() -> [String] {
    queue.sync {
      messagesByText
        .sorted { lhs, rhs in lhs.value > rhs.value }
        .map(\.key)
    }
  }
}

struct ScheduleRepository {
  private let client = ScheduleClient()
  private let store = SharedScheduleStore()
  private let teamLogoStore = TeamLogoStore()

  func refresh() async -> ScheduleSnapshot {
    await refresh(for: TeamCatalog.defaultTeam())
  }

  func refresh(for team: TeamDefinition) async -> ScheduleSnapshot {
    do {
      async let gamesTask = client.fetchGames(for: team)
      async let summaryTask = client.fetchTeamSummary(for: team)

      let games = try await gamesTask
      async let logoPrefetchTask: Void = teamLogoStore.prefetchLogos(for: games, sport: team.sport)
      let teamSummary = await summaryTask
      _ = await logoPrefetchTask

      let snapshot = ScheduleSnapshot(games: games, lastUpdated: Date(), errorMessage: nil, teamSummary: teamSummary)
      do {
        try store.save(snapshot, for: team.compositeID)
        await MainActor.run {
          WidgetCenter.shared.reloadTimelines(ofKind: "HomeTeamWidget")
        }
      } catch {
        RuntimeIssueCenter.report("Snapshot cache write failed for \(team.displayName): \(Self.describe(error))")
      }
      return snapshot
    } catch {
      let stale = store.load(for: team.compositeID)
      let reason = Self.describe(error)

      RuntimeIssueCenter.report("Refresh failed for \(team.displayName): \(reason)")
      if stale != nil {
        RuntimeIssueCenter.report("Using fallback cached data for \(team.displayName).")
      } else {
        RuntimeIssueCenter.report("No cached fallback data available for \(team.displayName).")
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
    currentSnapshot(for: TeamCatalog.defaultTeam())
  }

  func currentSnapshot(for team: TeamDefinition) -> ScheduleSnapshot {
    store.load(for: team.compositeID)
      ?? ScheduleSnapshot(games: [], lastUpdated: Date(), errorMessage: "No data yet", teamSummary: nil)
  }

  private static func describe(_ error: Error) -> String {
    if let decodingError = error as? DecodingError {
      return "Decoding error: \(describe(decodingError))"
    }

    if
      let localizedError = error as? LocalizedError,
      let description = localizedError.errorDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
      !description.isEmpty
    {
      return description
    }

    return error.localizedDescription
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
