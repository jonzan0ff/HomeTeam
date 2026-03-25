import AppIntents
import Foundation
import os

private let teamWidgetEntityLogger = Logger(
  subsystem: "com.jonzanoff.hometeam.widget",
  category: "TeamWidgetEntityQuery"
)

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

/// Uses `EntityQuery` only (not `EntityStringQuery`). On macOS, the string-matching configuration path has been flaky for large entity lists; search is not required for this picker.
struct TeamWidgetEntityQuery: EntityQuery {
  private static func widgetSettings() -> AppSettings {
    AppSettingsStore().load()
  }

  static func teamsForWidgetConfiguration() -> [TeamDefinition] {
    TeamCatalog.widgetPickerTeams(settings: widgetSettings())
  }

  func entities(for identifiers: [TeamWidgetEntity.ID]) async throws -> [TeamWidgetEntity] {
    WidgetPickerDebugLog.append("entities(for:) ids=\(identifiers.count)")
    let teams = identifiers.compactMap { TeamCatalog.team(withCompositeID: $0) }
    return Self.prioritizedEntities(from: teams)
  }

  func suggestedEntities() async throws -> [TeamWidgetEntity] {
    let settings = Self.widgetSettings()
    let definitions = Self.teamsForWidgetConfiguration()
    let entities = Self.prioritizedEntities(from: definitions)
    let msg =
      "suggestedEntities definitions=\(definitions.count) entities=\(entities.count) catalogTeams=\(TeamCatalog.teams.count) favoriteCount=\(settings.favoriteTeamCompositeIDs.count)"
    teamWidgetEntityLogger.notice("\(msg)")
    WidgetPickerDebugLog.append(msg)
    return entities
  }

  private static func prioritizedEntities(
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

struct HomeTeamWidgetIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "HomeTeam Widget"
  static var description = IntentDescription("Choose one team or driver for this widget instance.")
  static var parameterSummary: some ParameterSummary {
    Summary("Pick \(\.$team)")
  }

  @Parameter(title: "Team or driver", default: nil)
  var team: TeamWidgetEntity?

  var resolvedTeam: TeamDefinition {
    let settings = AppSettingsStore().load()
    return TeamCatalog.resolveWidgetSelectionTeam(
      configuredCompositeID: team?.id,
      settings: settings
    )
  }
}
