import AppIntents
import Foundation

struct TeamWidgetEntity: AppEntity, Identifiable, Hashable {
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Team")
  static var defaultQuery = TeamWidgetEntityQuery()

  let id: String
  let title: String
  let subtitle: String

  init(team: TeamDefinition) {
    id = team.compositeID
    title = team.displayName
    subtitle = team.sport.displayName
  }

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: LocalizedStringResource(stringLiteral: title),
      subtitle: LocalizedStringResource(stringLiteral: subtitle)
    )
  }
}

struct TeamWidgetEntityQuery: EntityStringQuery {
  private static func widgetSettings() -> AppSettings {
    AppSettingsStore().load()
  }

  static func teamsForWidgetConfiguration() -> [TeamDefinition] {
    TeamCatalog.widgetConfigurationTeams(settings: widgetSettings())
  }

  func entities(for identifiers: [TeamWidgetEntity.ID]) async throws -> [TeamWidgetEntity] {
    let teams = identifiers.compactMap { TeamCatalog.team(withCompositeID: $0) }
    return TeamWidgetEntityQuery.prioritizedEntities(from: teams)
  }

  func entities(matching string: String) async throws -> [TeamWidgetEntity] {
    let teamsForConfiguration = Self.teamsForWidgetConfiguration()
    let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    let teams = normalized.isEmpty
      ? teamsForConfiguration
      : teamsForConfiguration.filter { $0.searchText.contains(normalized) }
    return TeamWidgetEntityQuery.prioritizedEntities(from: teams)
  }

  func suggestedEntities() async throws -> [TeamWidgetEntity] {
    TeamWidgetEntityQuery.prioritizedEntities(from: Self.teamsForWidgetConfiguration())
  }

  static func prioritizedEntities(
    from teams: [TeamDefinition],
    pinnedCompositeIDs: [String] = []
  ) -> [TeamWidgetEntity] {
    TeamCatalog.prioritizedWidgetConfigurationTeams(
      from: teams,
      settings: widgetSettings(),
      pinnedCompositeIDs: pinnedCompositeIDs
    ).map(TeamWidgetEntity.init(team:))
  }
}

struct TeamWidgetEntityOptionsProvider: DynamicOptionsProvider {
  func results() async throws -> [TeamWidgetEntity] {
    TeamWidgetEntityQuery.prioritizedEntities(from: TeamWidgetEntityQuery.teamsForWidgetConfiguration())
  }
}

struct HomeTeamWidgetIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "HomeTeam Widget"
  static var description = IntentDescription("Choose one team or driver for this widget instance.")
  static var parameterSummary: some ParameterSummary {
    Summary("Pick \(\.$team)")
  }

  @Parameter(title: "Favorite", optionsProvider: TeamWidgetEntityOptionsProvider())
  var team: TeamWidgetEntity?

  var resolvedTeam: TeamDefinition {
    let settings = AppSettingsStore().load()
    return TeamCatalog.resolveWidgetSelectionTeam(
      configuredCompositeID: team?.id,
      settings: settings
    )
  }
}
