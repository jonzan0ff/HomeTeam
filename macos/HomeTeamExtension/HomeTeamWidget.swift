import WidgetKit
import SwiftUI
import OSLog

private let log = Logger(subsystem: "com.hometeam.app.extension", category: "widget")

// MARK: - Widget definition

struct HomeTeamWidget: Widget {
  let kind = "HomeTeamWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(
      kind: kind,
      intent: HomeTeamWidgetIntent.self,
      provider: HomeTeamTimelineProvider()
    ) { entry in
      HomeTeamWidgetEntryView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Team")
    .description("See upcoming and live games for your favourite teams.")
    .supportedFamilies([.systemLarge])
  }
}

// MARK: - Timeline provider

struct HomeTeamTimelineProvider: AppIntentTimelineProvider {

  func placeholder(in context: Context) -> HomeTeamEntry { .placeholder }

  func snapshot(for configuration: HomeTeamWidgetIntent, in context: Context) async -> HomeTeamEntry {
    makeEntry(for: configuration)
  }

  func timeline(for configuration: HomeTeamWidgetIntent, in context: Context) async -> Timeline<HomeTeamEntry> {
    let entry = makeEntry(for: configuration)
    let nextReload: Date
    if let next = entry.upcomingGames.first {
      nextReload = min(next.scheduledAt, Date().addingTimeInterval(1800))
    } else {
      nextReload = Date().addingTimeInterval(1800)
    }
    return Timeline(entries: [entry], policy: .after(nextReload))
  }

  // MARK: Private

  private func makeEntry(for config: HomeTeamWidgetIntent) -> HomeTeamEntry {
    let settings = try? AppGroupStore.read(AppSettings.self, from: AppGroupStore.settingsFilename)

    // Resolve team: configured selection → first favorite → nil (unconfigured)
    let teamID: String
    if let configured = config.team {
      teamID = configured.id
    } else if let first = settings?.favoriteTeamCompositeIDs.first {
      teamID = first
    } else {
      return .placeholder
    }

    guard let team = TeamCatalog.team(for: teamID) else { return .placeholder }

    let snapshot: ScheduleSnapshot
    do {
      snapshot = try AppGroupStore.read(ScheduleSnapshot.self, from: AppGroupStore.snapshotFilename)
      log.info("snapshot OK: \(snapshot.games.count) games, team=\(teamID)")
    } catch {
      log.error("snapshot READ FAILED: \(error)")
      snapshot = .empty
    }

    // Filter games for this team
    let teamGames: [HomeTeamGame]
    if team.sport.isRacing {
      teamGames = snapshot.games.filter { $0.sport == team.sport }
    } else {
      teamGames = snapshot.games.filter {
        $0.homeTeamID == team.espnTeamID || $0.awayTeamID == team.espnTeamID
      }
    }

    let now = Date()
    let live = teamGames.filter { $0.status == .live }
    let previous = teamGames
      .filter { $0.status == .final && $0.scheduledAt < now }
      .sorted { $0.scheduledAt > $1.scheduledAt }
    let upcoming = teamGames
      .filter { $0.status == .scheduled && $0.scheduledAt > now }
      .sorted { $0.scheduledAt < $1.scheduledAt }

    // Streaming filter for upcoming (only if user has services configured)
    let filteredUpcoming: [HomeTeamGame]
    let streamingKeys = Set(settings?.selectedStreamingServices ?? [])
    if streamingKeys.isEmpty {
      filteredUpcoming = upcoming
    } else {
      filteredUpcoming = upcoming.filter { game in
        game.broadcastNetworks.contains {
          StreamingServiceMatcher.isMatch(rawName: $0, selectedKeys: streamingKeys)
        }
      }
    }

    let teamSummary = snapshot.teamSummaries.first { $0.compositeID == team.compositeID }

    log.info("live=\(live.count) previous=\(previous.count) upcoming=\(filteredUpcoming.count) summary=\(teamSummary?.inlineDisplay ?? "nil")")

    return HomeTeamEntry(
      date: now,
      teamDefinition: team,
      teamSummary: teamSummary,
      isOffSeason: upcoming.isEmpty && !team.sport.isRacing,
      liveGames: live,
      previousGames: Array(previous.prefix(3)),
      upcomingGames: Array(filteredUpcoming.prefix(3)),
      fetchedAt: snapshot.fetchedAt,
      streamingKeys: streamingKeys
    )
  }
}

// MARK: - Entry

struct HomeTeamEntry: TimelineEntry {
  let date: Date
  let teamDefinition: TeamDefinition?
  let teamSummary: HomeTeamTeamSummary?
  let isOffSeason: Bool
  let liveGames: [HomeTeamGame]
  let previousGames: [HomeTeamGame]
  let upcomingGames: [HomeTeamGame]
  let fetchedAt: Date
  let streamingKeys: Set<String>

  var allUpcoming: [HomeTeamGame] { liveGames + upcomingGames }
  var isEmpty: Bool { previousGames.isEmpty && allUpcoming.isEmpty }

  static let placeholder = HomeTeamEntry(
    date: Date(),
    teamDefinition: nil,
    teamSummary: nil,
    isOffSeason: false,
    liveGames: [],
    previousGames: [],
    upcomingGames: [],
    fetchedAt: .distantPast,
    streamingKeys: []
  )
}
