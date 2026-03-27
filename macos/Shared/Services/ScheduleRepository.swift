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
    let favTeams = favs.compactMap { TeamCatalog.team(for: $0) }
    return snapshot.games.contains { game in
      guard game.status == .live else { return false }
      return favTeams.contains { t in
        if t.sport.isRacing { return game.sport == t.sport }
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
      let patchedGames = await patchLiveScores(into: merged.games)
      let finalSnapshot = ScheduleSnapshot(games: patchedGames, fetchedAt: merged.fetchedAt, teamSummaries: merged.teamSummaries)
      snapshotStore.save(finalSnapshot)
      await prefetchLogos(for: finalSnapshot.games)
      await prefetchRacingLogos(for: favorites)
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

  // MARK: - Live score overlay

  /// Fetches each sport's scoreboard for sports that have a live game in the snapshot,
  /// then overlays live scores + statusDetail onto matching games (matched by ESPN event ID).
  private func patchLiveScores(into games: [HomeTeamGame]) async -> [HomeTeamGame] {
    let liveSports = Set(games.filter { $0.status == .live && !$0.sport.isRacing }.map { $0.sport })
    guard !liveSports.isEmpty else { return games }

    var freshByID: [String: HomeTeamGame] = [:]
    await withTaskGroup(of: [HomeTeamGame].self) { group in
      for sport in liveSports {
        group.addTask {
          let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(sport.sportPath)/\(sport.leaguePath)/scoreboard")!
          guard let (data, _) = try? await URLSession.shared.data(from: url) else { return [] }
          return (try? ESPNScheduleParser.parse(data, sport: sport, teamID: "")) ?? []
        }
      }
      for await batch in group {
        for game in batch { freshByID[game.id] = game }
      }
    }

    return games.map { game in
      guard game.status == .live, !game.sport.isRacing,
            let fresh = freshByID[game.id] else { return game }
      return game.patching(homeScore: fresh.homeScore, awayScore: fresh.awayScore,
                           statusDetail: fresh.statusDetail)
    }
  }

  private func prefetchLogos(for games: [HomeTeamGame]) async {
    // Collect unique (sport, espnTeamID) pairs that don't already have a cached logo
    var seen = Set<String>()
    var needed: [(SupportedSport, String)] = []
    // Re-download if missing or stale (older than 30 days — catches any wrong-logo cache bugs)
    let staleThreshold = Date().addingTimeInterval(-7 * 24 * 3600)
    for game in games {
      guard !game.sport.isRacing else { continue }
      for teamID in [game.homeTeamID, game.awayTeamID] where !teamID.isEmpty {
        let key = "\(game.sport.rawValue)_\(teamID)"
        guard seen.insert(key).inserted else { continue }
        guard let dest = AppGroupStore.logoFileURL(sport: game.sport, espnTeamID: teamID) else { continue }
        let isStale = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.modificationDate] as? Date)
          .map { $0 < staleThreshold } ?? true
        if !FileManager.default.fileExists(atPath: dest.path) || isStale {
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

  /// Downloads F1 (SVG/PNG) and MotoGP (PNG) logos from GitHub Pages into the App Group container.
  /// Driven by favorite teams in the catalog — racing games have no team IDs in the schedule feed.
  private func prefetchRacingLogos(for compositeIDs: [String]) async {
    guard let dir = AppGroupStore.logosDirectoryURL else { return }
    let base = "https://jonzan0ff.github.io/HomeTeam/logos/teams"

    var seen = Set<String>()
    var needed: [(SupportedSport, String)] = []

    for cid in compositeIDs {
      guard let team = TeamCatalog.team(for: cid), team.sport.isRacing else { continue }
      guard seen.insert(team.espnTeamID).inserted else { continue }
      let exists: Bool
      if team.sport == .f1 {
        let svg = dir.appendingPathComponent("f1_\(team.espnTeamID).svg")
        let png = dir.appendingPathComponent("f1_\(team.espnTeamID).png")
        exists = FileManager.default.fileExists(atPath: svg.path) || FileManager.default.fileExists(atPath: png.path)
      } else {
        let png = dir.appendingPathComponent("motoGP_\(team.espnTeamID).png")
        exists = FileManager.default.fileExists(atPath: png.path)
      }
      if !exists { needed.append((team.sport, team.espnTeamID)) }
    }

    guard !needed.isEmpty else { return }
    print("[ScheduleRepository] Racing logo prefetch: \(needed.count) logo(s)")

    await withTaskGroup(of: Void.self) { group in
      for (sport, espnTeamID) in needed {
        group.addTask {
          if sport == .f1 {
            for ext in ["svg", "png"] {
              guard let src = URL(string: "\(base)/f1_\(espnTeamID).\(ext)") else { continue }
              let dest = dir.appendingPathComponent("f1_\(espnTeamID).\(ext)")
              do {
                let (data, response) = try await URLSession.shared.data(from: src)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                try data.write(to: dest, options: .atomic)
                return
              } catch { continue }
            }
          } else {
            guard let src = URL(string: "\(base)/motoGP_\(espnTeamID).png") else { return }
            let dest = dir.appendingPathComponent("motoGP_\(espnTeamID).png")
            do {
              let (data, response) = try await URLSession.shared.data(from: src)
              guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
              try data.write(to: dest, options: .atomic)
            } catch {}
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
