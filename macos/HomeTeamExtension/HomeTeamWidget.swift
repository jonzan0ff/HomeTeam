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
    .contentMarginsDisabled()
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

    let now = Date()
    let streamingKeys = Set(settings?.selectedStreamingServices ?? [])
    let filtered = WidgetGameFilter.filter(
      games: snapshot.games, for: team, streamingKeys: streamingKeys, now: now
    )

    let teamSummary = snapshot.teamSummaries.first { $0.compositeID == team.compositeID }

    log.info("streamingKeys=\(streamingKeys.sorted()) live=\(filtered.live.count) previous=\(filtered.previous.count) upcoming=\(filtered.upcoming.count)")

    return HomeTeamEntry(
      date: now,
      teamDefinition: team,
      teamSummary: teamSummary,
      isOffSeason: filtered.isOffSeason,
      liveGames: filtered.live,
      previousGames: filtered.previous,
      upcomingGames: filtered.upcoming,
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
