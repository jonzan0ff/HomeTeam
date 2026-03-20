import XCTest
final class ScheduleClientNetworkSmokeTests: XCTestCase {
  private var shouldRunNetworkTests: Bool {
    ProcessInfo.processInfo.environment["HOMETEAM_RUN_NETWORK_TESTS"] == "1"
  }

  func testMotoGPFetchForMarcMarquezDoesNotThrow() async throws {
    guard shouldRunNetworkTests else {
      throw XCTSkip("Set HOMETEAM_RUN_NETWORK_TESTS=1 to run live API smoke tests.")
    }

    guard let team = TeamCatalog.team(withCompositeID: "motogp:mgp-mmarquez") else {
      XCTFail("Missing TeamCatalog entry for Marc Marquez")
      return
    }

    let games = try await ScheduleClient().fetchGames(for: team)

    XCTAssertFalse(games.isEmpty, "MotoGP fetch returned no games; fallback feed may be broken.")
  }

  func testMotoGPUpcomingRowsAreSprintOrGrandPrixOnly() async throws {
    guard shouldRunNetworkTests else {
      throw XCTSkip("Set HOMETEAM_RUN_NETWORK_TESTS=1 to run live API smoke tests.")
    }

    guard let team = TeamCatalog.team(withCompositeID: "motogp:mgp-mmarquez") else {
      XCTFail("Missing TeamCatalog entry for Marc Marquez")
      return
    }

    let games = try await ScheduleClient().fetchGames(for: team)
    let upcoming = games
      .upcomingGames(now: Date(), limit: 8)
      .filter { $0.sport == .motogp }

    guard !upcoming.isEmpty else {
      throw XCTSkip("No upcoming MotoGP events found in live feed.")
    }

    XCTAssertTrue(
      upcoming.allSatisfy { labelIsSprintOrGrandPrix($0.homeTeam) },
      "MotoGP upcoming cards should only contain Sprint or Grand Prix sessions."
    )
  }

  func testF1ScheduledRowsDoNotExposeDriverAbbreviationPlaceholders() async throws {
    guard shouldRunNetworkTests else {
      throw XCTSkip("Set HOMETEAM_RUN_NETWORK_TESTS=1 to run live API smoke tests.")
    }

    guard let team = TeamCatalog.team(withCompositeID: "f1:5789") else {
      XCTFail("Missing TeamCatalog entry for Oliver Bearman")
      return
    }

    let games = try await ScheduleClient().fetchGames(for: team)
    let scheduled = games.filter { game in
      game.status == .scheduled
      && (game.racingResults?.isEmpty ?? true)
    }

    guard !scheduled.isEmpty else {
      throw XCTSkip("No scheduled F1 races without results available in feed.")
    }

    XCTAssertTrue(
      scheduled.prefix(3).allSatisfy {
        $0.awayAbbrev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && $0.homeAbbrev.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          && $0.homeTeam.trimmingCharacters(in: .whitespacesAndNewlines).count > 4
      },
      "Scheduled racing cards should show race names only (no driver placeholders)."
    )
  }

  func testF1PreviousRowsStayInSameSeasonAsUpcomingRows() async throws {
    guard shouldRunNetworkTests else {
      throw XCTSkip("Set HOMETEAM_RUN_NETWORK_TESTS=1 to run live API smoke tests.")
    }

    guard let team = TeamCatalog.team(withCompositeID: "f1:5789") else {
      XCTFail("Missing TeamCatalog entry for Oliver Bearman")
      return
    }

    let games = try await ScheduleClient().fetchGames(for: team)
    let now = Date()
    let upcoming = games.upcomingGames(now: now, limit: 5)
    guard let firstUpcoming = upcoming.first else {
      throw XCTSkip("No upcoming F1 rows available to infer active season.")
    }

    let previous = games.previousGames(now: now, limit: 5)
    guard !previous.isEmpty else {
      throw XCTSkip("No previous F1 rows available.")
    }

    let calendar = Calendar(identifier: .gregorian)
    let activeYear = calendar.component(.year, from: firstUpcoming.startTimeUTC)
    XCTAssertTrue(
      previous.allSatisfy { calendar.component(.year, from: $0.startTimeUTC) == activeYear },
      "F1 previous rows should stay in the active season year inferred from upcoming events."
    )
  }

  private func labelIsSprintOrGrandPrix(_ label: String) -> Bool {
    let normalized = label
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    return normalized.contains("sprint")
      || normalized.contains("grand prix")
      || normalized.hasSuffix(" gp")
  }
}
