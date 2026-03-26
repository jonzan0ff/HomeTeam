import Foundation
import Combine
import WidgetKit

// MARK: - Orchestrates multi-sport fetching, filtering, and snapshot persistence

@MainActor
final class ScheduleRepository: ObservableObject {
  static let shared = ScheduleRepository()

  @Published private(set) var isRefreshing = false
  @Published private(set) var lastError: Error?

  private let settingsStore = AppSettingsStore.shared
  private let snapshotStore = ScheduleSnapshotStore.shared

  private var autoRefreshTask: Task<Void, Never>?

  private init() {}

  // MARK: - Auto-refresh

  /// Call once at launch. Refreshes immediately, then:
  ///  • every 60 s while any favourite team has a live game
  ///  • every 60 min otherwise
  /// Subsequent calls are no-ops — only one loop ever runs.
  func startAutoRefresh() {
    guard autoRefreshTask == nil else { return }
    autoRefreshTask = Task {
      await refresh()
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(60))
        if hasLiveTrackedGame {
          await refresh()
        } else if Date().timeIntervalSince(snapshot.fetchedAt) >= 3600 {
          await refresh()
        }
      }
    }
  }

  private var hasLiveTrackedGame: Bool {
    let favs = settingsStore.settings.favoriteTeamCompositeIDs
    return snapshot.games.contains { game in
      guard game.status == .live else { return false }
      return favs.contains { cid in
        guard let t = TeamCatalog.team(for: cid) else { return false }
        return game.homeTeamID == t.espnTeamID || game.awayTeamID == t.espnTeamID
      }
    }
  }

  // MARK: - Public

  var snapshot: ScheduleSnapshot { snapshotStore.snapshot }

  /// Full refresh: fetch all sports for all selected teams.
  /// Uses non-destructive merge so an empty/failed response doesn't wipe cache.
  func refresh() async {
    guard !isRefreshing else { return }
    isRefreshing = true
    lastError = nil
    defer { isRefreshing = false }

    let settings = settingsStore.settings
    let favorites = settings.favoriteTeamCompositeIDs
    print("[ScheduleRepository] 🔍 favorites: \(favorites)")
    for cid in favorites {
      print("[ScheduleRepository] 🔍 lookup '\(cid)' → \(TeamCatalog.team(for: cid) != nil ? "found" : "NIL")")
    }

    do {
      // Fetch games, standings, and logos in parallel
      async let gamesResult = fetchAll(for: favorites)
      async let summariesResult = fetchAllStandings(for: favorites)
      let (games, summaries) = try await (gamesResult, summariesResult)
      let newSnapshot = ScheduleSnapshot(games: games, fetchedAt: Date(), teamSummaries: summaries)
      let merged = snapshotStore.snapshot.mergingNondestructively(with: newSnapshot)
      snapshotStore.save(merged)
      await prefetchLogos(for: merged.games)
      WidgetCenter.shared.reloadAllTimelines()
    } catch {
      lastError = error
    }
  }

  // MARK: - Private

  private func fetchAllStandings(for compositeIDs: [String]) async -> [HomeTeamTeamSummary] {
    // One standings fetch per unique compositeID (dedup racing sports — same sport, different drivers)
    var seen = Set<String>()
    var teams: [TeamDefinition] = []
    for cid in compositeIDs {
      guard let team = TeamCatalog.team(for: cid) else { continue }
      // Racing: one fetch per sport, not per driver
      let key = team.sport.isRacing ? team.sport.rawValue : cid
      if seen.insert(key).inserted { teams.append(team) }
    }
    return await withTaskGroup(of: HomeTeamTeamSummary?.self) { group in
      for team in teams {
        group.addTask { await ScheduleClient.fetchStandings(for: team) }
      }
      var results: [HomeTeamTeamSummary] = []
      for await summary in group {
        if let s = summary { results.append(s) }
      }
      return results
    }
  }

  private func fetchAll(for compositeIDs: [String]) async throws -> [HomeTeamGame] {
    var all: [HomeTeamGame] = []
    var fetchError: Error?

    // Group by sport, deduplicating by espnTeamID (racing entries share IDs across drivers)
    var bySport: [SupportedSport: Set<String>] = [:]
    for cid in compositeIDs {
      if let team = TeamCatalog.team(for: cid) {
        bySport[team.sport, default: []].insert(team.espnTeamID)
      }
    }

    await withTaskGroup(of: Result<[HomeTeamGame], Error>.self) { group in
      for (sport, espnTeamIDs) in bySport {
        for espnTeamID in espnTeamIDs {
          group.addTask {
            do {
              let games = try await self.fetch(sport: sport, teamID: espnTeamID)
              return .success(games)
            } catch {
              return .failure(error)
            }
          }
        }
        // Racing sports fetch once (no per-team)
        if sport == .f1 {
          group.addTask {
            do { return .success(try await ScheduleClient.fetchF1()) }
            catch { return .failure(error) }
          }
        }
        if sport == .motoGP {
          group.addTask {
            do { return .success(try await ScheduleClient.fetchMotoGP()) }
            catch { return .failure(error) }
          }
        }
      }

      for await result in group {
        switch result {
        case .success(let games): all.append(contentsOf: games)
        case .failure(let e):
          print("[ScheduleRepository] ❌ fetch error: \(e)")
          fetchError = e
        }
      }
    }

    // Deduplicate by game ID (two drivers of same team produce identical events)
    let unique = Array(Dictionary(grouping: all, by: \.id).compactMap(\.value.first))
    if unique.isEmpty, let e = fetchError { throw e }
    return unique
  }

  private func prefetchLogos(for games: [HomeTeamGame]) async {
    // Collect unique (sport, espnTeamID) pairs that don't already have a cached logo
    var seen = Set<String>()
    var needed: [(SupportedSport, String)] = []
    for game in games {
      guard !game.sport.isRacing else { continue }
      for teamID in [game.homeTeamID, game.awayTeamID] where !teamID.isEmpty {
        let key = "\(game.sport.rawValue)_\(teamID)"
        guard seen.insert(key).inserted else { continue }
        if let dest = AppGroupStore.logoFileURL(sport: game.sport, espnTeamID: teamID),
           !FileManager.default.fileExists(atPath: dest.path) {
          needed.append((game.sport, teamID))
        }
      }
    }
    guard !needed.isEmpty else { return }
    print("[ScheduleRepository] logo prefetch: \(needed.count) missing logo(s)")
    await withTaskGroup(of: Void.self) { group in
      for (sport, teamID) in needed {
        group.addTask {
          guard let dest = AppGroupStore.logoFileURL(sport: sport, espnTeamID: teamID),
                let src = URL(string: "https://jonzan0ff.github.io/HomeTeam/logos/teams/\(sport.rawValue)_\(teamID).png")
          else { return }
          do {
            let (data, response) = try await URLSession.shared.data(from: src)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            try data.write(to: dest, options: .atomic)
          } catch {
            // Non-fatal: logo fetch failures never block schedule data
          }
        }
      }
    }
  }

  private func fetch(sport: SupportedSport, teamID: String) async throws -> [HomeTeamGame] {
    switch sport {
    case .nhl:          return try await ScheduleClient.fetchNHL(teamID: teamID)
    case .mlb:          return try await ScheduleClient.fetchMLB(teamID: teamID)
    case .nfl:          return try await ScheduleClient.fetchNFL(teamID: teamID)
    case .nba:          return try await ScheduleClient.fetchNBA(teamID: teamID)
    case .mls:          return try await ScheduleClient.fetchMLS(teamID: teamID)
    case .premierLeague:return try await ScheduleClient.fetchPL(teamID: teamID)
    case .f1, .motoGP:  return []  // handled above as single-fetch
    }
  }
}
