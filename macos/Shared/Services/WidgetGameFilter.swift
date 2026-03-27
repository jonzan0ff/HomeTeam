import Foundation

/// Pure filtering logic extracted from the widget timeline provider for testability.
/// All methods are deterministic — `now` is injected, no side effects.
enum WidgetGameFilter {

  struct Result {
    let live: [HomeTeamGame]
    let previous: [HomeTeamGame]
    let upcoming: [HomeTeamGame]
    let isOffSeason: Bool
  }

  /// Filters and splits games for a given team, applying streaming filter and limits.
  static func filter(
    games: [HomeTeamGame],
    for team: TeamDefinition,
    streamingKeys: Set<String>,
    now: Date
  ) -> Result {
    let teamGames = filterForTeam(games: games, team: team)
    let live = teamGames.filter { $0.status == .live }
    let previous = teamGames
      .filter { $0.status == .final && $0.scheduledAt < now }
      .sorted { $0.scheduledAt > $1.scheduledAt }
    let upcoming = teamGames
      .filter { $0.status == .scheduled && $0.scheduledAt > now }
      .sorted { $0.scheduledAt < $1.scheduledAt }

    let filteredUpcoming: [HomeTeamGame]
    if streamingKeys.isEmpty {
      filteredUpcoming = upcoming
    } else {
      filteredUpcoming = upcoming.filter { game in
        game.broadcastNetworks.contains {
          StreamingServiceMatcher.isMatch(rawName: $0, selectedKeys: streamingKeys)
        }
      }
    }

    return Result(
      live: live,
      previous: Array(previous.prefix(3)),
      upcoming: Array(filteredUpcoming.prefix(3)),
      isOffSeason: upcoming.isEmpty && !team.sport.isRacing
    )
  }

  /// Filters games relevant to a team: racing matches by sport, team sports match by ESPN team ID.
  static func filterForTeam(games: [HomeTeamGame], team: TeamDefinition) -> [HomeTeamGame] {
    if team.sport.isRacing {
      return games.filter { $0.sport == team.sport }
    } else {
      return games.filter {
        $0.homeTeamID == team.espnTeamID || $0.awayTeamID == team.espnTeamID
      }
    }
  }
}
