import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Widget timeline entry
// Lives in Shared/ so snapshot tests can render HomeTeamWidgetEntryView without
// importing the extension target. Conditional WidgetKit import preserves TimelineEntry
// conformance in the extension while allowing plain struct usage in tests.

struct HomeTeamEntry: Equatable {
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

#if canImport(WidgetKit)
extension HomeTeamEntry: TimelineEntry {}
#endif
