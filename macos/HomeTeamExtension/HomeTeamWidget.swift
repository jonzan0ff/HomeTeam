import SwiftUI
import WidgetKit

struct HomeTeamEntry: TimelineEntry {
  let date: Date
  let snapshot: ScheduleSnapshot
  let settings: AppSettings
  let team: TeamDefinition
  let isTeamSelectionConfigured: Bool
}

struct HomeTeamProvider: AppIntentTimelineProvider {
  typealias Intent = HomeTeamWidgetIntent

  private let repository = ScheduleRepository()
  private let settingsStore = AppSettingsStore()

  func placeholder(in context: Context) -> HomeTeamEntry {
    HomeTeamEntry(
      date: Date(),
      snapshot: ScheduleSnapshot(games: [], lastUpdated: Date(), errorMessage: nil, teamSummary: nil),
      settings: .default,
      team: TeamCatalog.defaultTeam(),
      isTeamSelectionConfigured: false
    )
  }

  func snapshot(for configuration: HomeTeamWidgetIntent, in context: Context) async -> HomeTeamEntry {
    await makeEntry(configuration: configuration, referenceDate: Date())
  }

  func timeline(for configuration: HomeTeamWidgetIntent, in context: Context) async -> Timeline<HomeTeamEntry> {
    let now = Date()
    let entry = await makeEntry(configuration: configuration, referenceDate: now)
    let refreshDate = nextRefreshDate(from: entry.snapshot, now: now)
    return Timeline(entries: [entry], policy: .after(refreshDate))
  }

  private func makeEntry(configuration: HomeTeamWidgetIntent, referenceDate: Date) async -> HomeTeamEntry {
    let isTeamSelectionConfigured = configuration.team != nil
    let team = configuration.resolvedTeam
    let settings = settingsStore.load()

    guard isTeamSelectionConfigured else {
      return HomeTeamEntry(
        date: referenceDate,
        snapshot: ScheduleSnapshot(games: [], lastUpdated: referenceDate, errorMessage: nil, teamSummary: nil),
        settings: settings,
        team: team,
        isTeamSelectionConfigured: false
      )
    }

    let snapshot = await repository.refresh(for: team)
    settingsStore.recordRecentTeam(team.compositeID)

    return HomeTeamEntry(
      date: referenceDate,
      snapshot: snapshot,
      settings: settings,
      team: team,
      isTeamSelectionConfigured: true
    )
  }

  private func nextRefreshDate(from snapshot: ScheduleSnapshot, now: Date) -> Date {
    if snapshot.hasLiveGame {
      return now.addingTimeInterval(5 * 60)
    }

    return now.addingTimeInterval(24 * 60 * 60)
  }
}

struct HomeTeamWidget: Widget {
  let kind: String = "HomeTeamWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: HomeTeamWidgetIntent.self, provider: HomeTeamProvider()) { entry in
      HomeTeamWidgetView(entry: entry)
    }
    .configurationDisplayName("HomeTeam")
    .description("Track one team or driver.")
    .supportedFamilies([.systemLarge])
    .containerBackgroundRemovable(false)
  }
}

private struct HomeTeamWidgetView: View {
  let entry: HomeTeamEntry

  private var contentState: HomeTeamWidgetContentState {
    HomeTeamWidgetContentState(
      referenceDate: entry.date,
      snapshot: entry.snapshot,
      settings: entry.settings,
      team: entry.team,
      isTeamSelectionConfigured: entry.isTeamSelectionConfigured
    )
  }

  var body: some View {
    HomeTeamWidgetContentView(state: contentState)
      .containerBackground(HomeTeamWidgetBackground.gradient, for: .widget)
  }
}
