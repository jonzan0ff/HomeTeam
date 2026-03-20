import Foundation
import WidgetKit

struct TeamScheduleSection: Identifiable {
  let team: TeamDefinition
  let snapshot: ScheduleSnapshot
  let previousGames: [HomeTeamGame]
  let upcomingGames: [HomeTeamGame]

  var id: String {
    team.compositeID
  }

  var hasVisibleGames: Bool {
    !previousGames.isEmpty || !upcomingGames.isEmpty
  }

  var teamSummaryLine: String? {
    snapshot.teamSummary?.inlineDisplay
  }
}

@MainActor
final class AppViewModel: ObservableObject {
  @Published private(set) var snapshotsByTeamID: [String: ScheduleSnapshot]
  @Published private(set) var lastUpdated = Date()
  @Published private(set) var runtimeIssueMessages: [String]

  private let repository: ScheduleRepository
  private let networkRefreshEnabled: Bool
  private let widgetReloadEnabled: Bool
  private var autoRefreshTask: Task<Void, Never>?
  private var trackedTeamCompositeIDs: [String]
  private var runtimeIssueObserver: NSObjectProtocol?

  init(
    repository: ScheduleRepository = ScheduleRepository(),
    networkRefreshEnabled: Bool = true,
    widgetReloadEnabled: Bool = true
  ) {
    self.repository = repository
    self.networkRefreshEnabled = networkRefreshEnabled
    self.widgetReloadEnabled = widgetReloadEnabled
    let defaultTeam = TeamCatalog.defaultTeam().compositeID
    trackedTeamCompositeIDs = [defaultTeam]
    snapshotsByTeamID = [:]
    runtimeIssueMessages = RuntimeIssueCenter.allMessages()
    let snapshot = repository.currentSnapshot(for: TeamCatalog.defaultTeam())
    snapshotsByTeamID[defaultTeam] = snapshot
    lastUpdated = snapshot.lastUpdated
    runtimeIssueObserver = NotificationCenter.default.addObserver(
      forName: RuntimeIssueCenter.didChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor [weak self] in
        self?.runtimeIssueMessages = RuntimeIssueCenter.allMessages()
      }
    }
  }

  deinit {
    autoRefreshTask?.cancel()
    if let runtimeIssueObserver {
      NotificationCenter.default.removeObserver(runtimeIssueObserver)
    }
  }

  var lastUpdatedLabel: String {
    lastUpdated.formatted(date: .omitted, time: .shortened)
  }

  var hasRuntimeIssues: Bool {
    !combinedIssueMessages.isEmpty
  }

  var runtimeIssueCount: Int {
    combinedIssueMessages.count
  }

  var runtimeIssueHelpText: String {
    guard hasRuntimeIssues else {
      return "Refresh now"
    }
    return combinedIssueMessages.joined(separator: "\n")
  }

  var runtimeIssueDescription: String {
    guard hasRuntimeIssues else {
      return "No runtime data issues detected."
    }
    return combinedIssueMessages.enumerated()
      .map { index, message in
        "\(index + 1). \(message)"
      }
      .joined(separator: "\n\n")
  }

  func loadInitialSnapshotsIfNeeded(for teamCompositeIDs: [String]) async {
    updateTrackedTeams(teamCompositeIDs)
    guard networkRefreshEnabled else {
      refreshFromCurrentSnapshots()
      return
    }

    startAutoRefreshLoopIfNeeded()
    await refresh()
  }

  func teamSections(
    favoriteTeamCompositeIDs: [String],
    hideDuringOffseasonTeamCompositeIDs: Set<String> = [],
    selectedServiceLookup: Set<String> = []
  ) -> [TeamScheduleSection] {
    let teams = resolvedTeams(from: favoriteTeamCompositeIDs)
    return teams.compactMap { team in
      let snapshot = snapshotsByTeamID[team.compositeID] ?? repository.currentSnapshot(for: team)
      if hideDuringOffseasonTeamCompositeIDs.contains(team.compositeID), isOutOfSeason(snapshot: snapshot) {
        return nil
      }

      let previousGames = snapshot.games.previousGames()
      let upcomingGames = snapshot.games.upcomingGames(selectedServiceLookup: selectedServiceLookup)

      return TeamScheduleSection(
        team: team,
        snapshot: snapshot,
        previousGames: previousGames,
        upcomingGames: upcomingGames
      )
    }
  }

  func hasVisibleGames(
    favoriteTeamCompositeIDs: [String],
    hideDuringOffseasonTeamCompositeIDs: Set<String> = [],
    selectedServiceLookup: Set<String> = []
  ) -> Bool {
    teamSections(
      favoriteTeamCompositeIDs: favoriteTeamCompositeIDs,
      hideDuringOffseasonTeamCompositeIDs: hideDuringOffseasonTeamCompositeIDs,
      selectedServiceLookup: selectedServiceLookup
    ).contains(where: \.hasVisibleGames)
  }

  func refresh(tracking teamCompositeIDs: [String]? = nil) async {
    if let teamCompositeIDs {
      updateTrackedTeams(teamCompositeIDs)
    }

    RuntimeIssueCenter.clear()

    guard networkRefreshEnabled else {
      refreshFromCurrentSnapshots()
      return
    }

    let teams = resolvedTrackedTeams()
    var refreshedSnapshots: [String: ScheduleSnapshot] = [:]
    var latestUpdate = Date.distantPast

    for team in teams {
      let snapshot = await repository.refresh(for: team)
      refreshedSnapshots[team.compositeID] = snapshot
      latestUpdate = max(latestUpdate, snapshot.lastUpdated)
    }

    snapshotsByTeamID = refreshedSnapshots
    if latestUpdate != .distantPast {
      lastUpdated = latestUpdate
    }
    if widgetReloadEnabled {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  func teamErrorMessages(
    favoriteTeamCompositeIDs: [String],
    hideDuringOffseasonTeamCompositeIDs: Set<String> = []
  ) -> [String] {
    let teams = resolvedTeams(from: favoriteTeamCompositeIDs).filter { team in
      if !hideDuringOffseasonTeamCompositeIDs.contains(team.compositeID) {
        return true
      }
      let snapshot = snapshotsByTeamID[team.compositeID] ?? repository.currentSnapshot(for: team)
      return !isOutOfSeason(snapshot: snapshot)
    }

    return teams.compactMap { team in
      guard let message = snapshotsByTeamID[team.compositeID]?.errorMessage else {
        return nil
      }
      return "\(team.displayName): \(message)"
    }
  }

  private var combinedIssueMessages: [String] {
    dedupedMessages(runtimeIssueMessages + snapshotIssueMessages)
  }

  private var snapshotIssueMessages: [String] {
    snapshotsByTeamID.compactMap { compositeID, snapshot in
      guard let message = snapshot.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty else {
        return nil
      }
      let teamName = TeamCatalog.team(withCompositeID: compositeID)?.displayName ?? compositeID
      return "\(teamName): \(message)"
    }
    .sorted()
  }

  private func dedupedMessages(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var ordered: [String] = []
    for value in values {
      if seen.insert(value).inserted {
        ordered.append(value)
      }
    }
    return ordered
  }

  private func startAutoRefreshLoopIfNeeded() {
    guard networkRefreshEnabled else {
      return
    }

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
    let snapshots = Array(snapshotsByTeamID.values)

    if snapshots.contains(where: \.hasLiveGame) {
      return 5 * 60
    }

    if !snapshots.isEmpty, snapshots.allSatisfy({ $0.errorMessage != nil && $0.games.isEmpty }) {
      return 30 * 60
    }

    return 24 * 60 * 60
  }

  private func updateTrackedTeams(_ teamCompositeIDs: [String]) {
    trackedTeamCompositeIDs = resolvedTeams(from: teamCompositeIDs).map(\.compositeID)
  }

  private func resolvedTrackedTeams() -> [TeamDefinition] {
    let teams = resolvedTeams(from: trackedTeamCompositeIDs)
    if !teams.isEmpty {
      return teams
    }

    return [TeamCatalog.defaultTeam()]
  }

  private func resolvedTeams(from compositeIDs: [String]) -> [TeamDefinition] {
    var seen = Set<String>()
    var teams: [TeamDefinition] = []

    for compositeID in compositeIDs {
      guard
        let team = TeamCatalog.team(withCompositeID: compositeID),
        seen.insert(team.compositeID).inserted
      else {
        continue
      }

      teams.append(team)
    }

    return teams
  }

  private func isOutOfSeason(snapshot: ScheduleSnapshot, now: Date = Date()) -> Bool {
    if snapshot.games.contains(where: { $0.status == .live }) {
      return false
    }

    let upcoming = snapshot.games
      .filter { $0.startTimeUTC >= now }
      .sorted { $0.startTimeUTC < $1.startTimeUTC }
    if let nextGame = upcoming.first {
      let daysUntilNext = now.distance(to: nextGame.startTimeUTC) / (60 * 60 * 24)
      return daysUntilNext > 45
    }

    guard let mostRecentFinal = snapshot.games
      .filter({ $0.status == .final && $0.startTimeUTC <= now })
      .map(\.startTimeUTC)
      .max()
    else {
      return false
    }

    let daysSinceLastFinal = mostRecentFinal.distance(to: now) / (60 * 60 * 24)
    return daysSinceLastFinal > 30
  }

  private func refreshFromCurrentSnapshots() {
    let teams = resolvedTrackedTeams()
    var loadedSnapshots: [String: ScheduleSnapshot] = [:]
    var latestUpdate = Date.distantPast

    for team in teams {
      let snapshot = repository.currentSnapshot(for: team)
      loadedSnapshots[team.compositeID] = snapshot
      latestUpdate = max(latestUpdate, snapshot.lastUpdated)
    }

    snapshotsByTeamID = loadedSnapshots
    if latestUpdate != .distantPast {
      lastUpdated = latestUpdate
    }
  }
}
