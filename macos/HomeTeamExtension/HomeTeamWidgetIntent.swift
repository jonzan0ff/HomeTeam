import AppIntents
import WidgetKit

// MARK: - Widget configuration intent

struct HomeTeamWidgetIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource       = "HomeTeam"
  static var description = IntentDescription("Choose a team to follow in this widget.")

  @Parameter(title: "Team")
  var team: TeamEntity?
}

// MARK: - TeamEntity

struct TeamEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Team"
  static var defaultQuery = TeamEntityQuery()

  let id: String          // compositeID e.g. "nhl:6"
  let displayString: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(displayString)")
  }
}

struct TeamEntityQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [TeamEntity] {
    identifiers.compactMap { id in
      TeamCatalog.team(for: id).map { t in
        TeamEntity(id: t.compositeID, displayString: t.sport.isRacing ? t.raceLabel : t.displayName)
      }
    }
  }

  func suggestedEntities() async throws -> [TeamEntity] {
    let favoriteIDs: [String]
    if let settings = try? AppGroupStore.read(AppSettings.self, from: AppGroupStore.settingsFilename) {
      favoriteIDs = settings.favoriteTeamCompositeIDs
    } else {
      favoriteIDs = []
    }
    let source = favoriteIDs.isEmpty ? TeamCatalog.all.map(\.compositeID) : favoriteIDs
    return source.compactMap { id in
      TeamCatalog.team(for: id).map { t in
        TeamEntity(id: t.compositeID, displayString: t.sport.isRacing ? t.raceLabel : t.displayName)
      }
    }
  }
}
