import XCTest
import SwiftUI
import AppKit
import CryptoKit
import WidgetKit
final class StreamingFilterTests: XCTestCase {
  func testDefaultSettingsStartWithoutFavoriteTeams() {
    XCTAssertTrue(AppSettings.default.favoriteTeamCompositeIDs.isEmpty)
    XCTAssertFalse(AppSettings.default.meetsOnboardingRequirements)
  }

  func testOnboardingRequiresFavoriteTeam() {
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = []
    settings.selectedStreamingServices = ["Hulu"]

    XCTAssertFalse(settings.meetsOnboardingRequirements)
  }

  func testOnboardingRequiresStreamingProvider() {
    var settings = AppSettings.default
    settings.selectedStreamingServices = []

    XCTAssertFalse(settings.meetsOnboardingRequirements)
  }

  func testOnboardingCompletesWithFavoritesAndProvidersEvenWithoutZip() {
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = [TeamCatalog.defaultTeamCompositeID]
    settings.selectedStreamingServices = ["Hulu"]
    settings.zipCode = ""
    settings.city = nil
    settings.state = nil

    XCTAssertTrue(settings.meetsOnboardingRequirements)
  }

  func testPersistedReloadKeepsOnboardingCompletionWithoutZip() {
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("HomeTeam-OnboardingTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let store = AppSettingsStore(customDirectoryURL: tempDirectory, cloudSyncEnabled: false)
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = [TeamCatalog.defaultTeamCompositeID]
    settings.selectedStreamingServices = ["Hulu", "HBO"]
    settings.zipCode = ""
    settings.city = nil
    settings.state = nil

    store.save(settings)
    let reloaded = store.load()

    XCTAssertEqual(reloaded.favoriteTeamCompositeIDs, settings.favoriteTeamCompositeIDs)
    XCTAssertEqual(reloaded.selectedStreamingServices, settings.selectedStreamingServices)
    XCTAssertEqual(reloaded.zipCode, "")
    XCTAssertTrue(reloaded.meetsOnboardingRequirements)
  }

  func testPersistedReloadKeepsEmptyFavoritesForOnboarding() {
    let tempDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("HomeTeam-EmptyFavorites-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let store = AppSettingsStore(customDirectoryURL: tempDirectory, cloudSyncEnabled: false)
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = []
    settings.selectedStreamingServices = ["Hulu"]

    store.save(settings)
    let reloaded = store.load()

    XCTAssertEqual(reloaded.favoriteTeamCompositeIDs, [])
    XCTAssertFalse(reloaded.meetsOnboardingRequirements)
  }

  func testPassesStreamingFilterUsesSelectedServicesOnly() {
    let huluGame = makeGame(id: "hulu", services: ["Hulu"])
    let espnGame = makeGame(id: "espn", services: ["ESPN+"])
    let selected: Set<String> = ["hulu"]

    XCTAssertTrue(huluGame.passesStreamingFilter(selectedServiceLookup: selected))
    XCTAssertFalse(espnGame.passesStreamingFilter(selectedServiceLookup: selected))
  }

  func testUnknownServiceDoesNotPassWhenUserSelectedServices() {
    let game = makeGame(id: "unknown", services: ["Regional Sports Network"])
    let selected: Set<String> = ["apple tv"]

    XCTAssertFalse(game.passesStreamingFilter(selectedServiceLookup: selected))
  }

  func testUnknownServicePassesWhenNoSelectedServices() {
    let game = makeGame(id: "unknown", services: ["Regional Sports Network"])

    XCTAssertTrue(game.passesStreamingFilter(selectedServiceLookup: []))
  }

  func testPreferredStreamingServiceUsesSelectedMatch() {
    let game = makeGame(id: "primary", services: ["ESPN+", "Apple TV", "Hulu"])
    let selected: Set<String> = ["apple tv"]

    XCTAssertEqual(game.preferredStreamingService(selectedServiceLookup: selected), "Apple TV")
  }

  func testAppleTVNormalizationVariants() {
    XCTAssertEqual(AppSettings.normalizedServiceName("Apple TV+"), "apple tv")
    XCTAssertEqual(AppSettings.normalizedServiceName("APPLETV"), "apple tv")
    XCTAssertEqual(AppSettings.normalizedServiceName("Apple TV"), "apple tv")
  }

  func testHBOAliasesNormalizeAndPassFilter() {
    XCTAssertEqual(AppSettings.normalizedServiceName("TNT"), "hbo")
    XCTAssertEqual(AppSettings.normalizedServiceName("truTV"), "hbo")

    let game = makeGame(id: "tnt", services: ["TNT"])
    let selected: Set<String> = ["hbo"]

    XCTAssertTrue(game.passesStreamingFilter(selectedServiceLookup: selected))
    XCTAssertEqual(game.preferredStreamingService(selectedServiceLookup: selected), "HBO")
  }

  func testUpcomingSelectionFiltersBeforeLimit() {
    let now = Date(timeIntervalSince1970: 0)
    let games = [
      makeGame(id: "g1", services: ["ESPN+"], startTime: now.addingTimeInterval(60)),
      makeGame(id: "g2", services: ["Apple TV"], startTime: now.addingTimeInterval(120)),
      makeGame(id: "g3", services: ["TNT"], startTime: now.addingTimeInterval(180)),
      makeGame(id: "g4", services: ["Hulu"], startTime: now.addingTimeInterval(240)),
    ]

    let filtered = games.upcomingGames(now: now, limit: 3, selectedServiceLookup: ["hbo"])

    XCTAssertEqual(filtered.map(\.id), ["g3"])
  }

  func testUpcomingGamesExcludeFutureFinalRows() {
    let now = Date(timeIntervalSince1970: 0)
    let games = [
      makeGame(id: "finalFuture", services: ["TNT"], startTime: now.addingTimeInterval(60), status: .final),
      makeGame(id: "scheduled", services: ["HBO"], startTime: now.addingTimeInterval(120), status: .scheduled),
    ]

    let upcoming = games.upcomingGames(now: now, limit: 3)

    XCTAssertEqual(upcoming.map(\.id), ["scheduled"])
  }

  func testRacingPreviousGamesUseActiveSeasonYear() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 19, hour: 12))!

    let oldSeasonFinal = makeGame(
      id: "f1-2025-finale",
      services: [],
      startTime: calendar.date(from: DateComponents(year: 2025, month: 12, day: 7, hour: 15))!,
      status: .final,
      sport: .f1,
      homeTeam: "Abu Dhabi Grand Prix"
    )
    let currentSeasonFinal = makeGame(
      id: "f1-2026-round1",
      services: [],
      startTime: calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 15))!,
      status: .final,
      sport: .f1,
      homeTeam: "Australian Grand Prix"
    )
    let currentSeasonUpcoming = makeGame(
      id: "f1-2026-round2",
      services: [],
      startTime: calendar.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 15))!,
      status: .scheduled,
      sport: .f1,
      homeTeam: "Chinese Grand Prix"
    )

    let previous = [oldSeasonFinal, currentSeasonFinal, currentSeasonUpcoming]
      .previousGames(now: now, limit: 3)

    XCTAssertEqual(previous.map(\.id), ["f1-2026-round1"])
  }

  func testLegacyRacingRowsWithoutExplicitSportStillUseActiveSeasonYear() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 19, hour: 12))!

    let oldSeasonFinal = makeGame(
      id: "f1-2025-finale",
      services: [],
      startTime: calendar.date(from: DateComponents(year: 2025, month: 12, day: 7, hour: 15))!,
      status: .final,
      sport: nil,
      homeTeam: "Abu Dhabi Grand Prix"
    )
    let currentSeasonFinal = makeGame(
      id: "f1-2026-round1",
      services: [],
      startTime: calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 15))!,
      status: .final,
      sport: nil,
      homeTeam: "Australian Grand Prix"
    )
    let currentSeasonUpcoming = makeGame(
      id: "f1-2026-round2",
      services: [],
      startTime: calendar.date(from: DateComponents(year: 2026, month: 3, day: 22, hour: 15))!,
      status: .scheduled,
      sport: nil,
      homeTeam: "Chinese Grand Prix"
    )

    let previous = [oldSeasonFinal, currentSeasonFinal, currentSeasonUpcoming]
      .previousGames(now: now, limit: 3)

    XCTAssertEqual(previous.map(\.id), ["f1-2026-round1"])
  }

  func testMotoGPUpcomingRowsOnlyIncludeSprintOrRaceSessions() {
    let now = Date(timeIntervalSince1970: 0)
    let games = [
      makeGame(
        id: "motogp-practice",
        services: [],
        startTime: now.addingTimeInterval(60),
        status: .scheduled,
        sport: .motogp,
        homeTeam: "Brazil Practice 1"
      ),
      makeGame(
        id: "motogp-sprint",
        services: [],
        startTime: now.addingTimeInterval(120),
        status: .scheduled,
        sport: .motogp,
        homeTeam: "Brazil Grand Prix Sprint"
      ),
      makeGame(
        id: "motogp-gp",
        services: [],
        startTime: now.addingTimeInterval(180),
        status: .scheduled,
        sport: .motogp,
        homeTeam: "Brazil Grand Prix"
      ),
      makeGame(
        id: "motogp-warmup",
        services: [],
        startTime: now.addingTimeInterval(240),
        status: .scheduled,
        sport: .motogp,
        homeTeam: "Brazil Warm Up"
      ),
    ]

    let upcoming = games.upcomingGames(now: now, limit: 4)

    XCTAssertEqual(upcoming.map(\.id), ["motogp-sprint", "motogp-gp"])
  }

  func testCanonicalCompositeIDMapsLegacyIdentifiers() {
    XCTAssertEqual(TeamCatalog.canonicalCompositeID(for: "f1_5789"), "f1:5789")
    XCTAssertEqual(TeamCatalog.canonicalCompositeID(for: "mgp-mmarquez"), "motogp:mgp-mmarquez")
    XCTAssertEqual(TeamCatalog.canonicalCompositeID(for: "caps"), "nhl:23")
  }

  func testPreferredWidgetFallbackTeamUsesFavoriteWithSnapshotData() {
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = ["nhl:23", "f1:5789", "motogp:mgp-mmarquez"]
    settings.recentTeamCompositeIDs = ["nfl:28"]

    let resolved = TeamCatalog.preferredWidgetFallbackTeam(settings: settings) { compositeID in
      compositeID == "f1:5789"
    }

    XCTAssertEqual(resolved?.compositeID, "f1:5789")
  }

  func testPreferredWidgetFallbackTeamPrefersFavoriteOverRecentWhenFavoriteHasNoSnapshot() {
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = ["f1:5789"]
    settings.recentTeamCompositeIDs = ["f1:5592"]

    let resolved = TeamCatalog.preferredWidgetFallbackTeam(settings: settings) { compositeID in
      compositeID == "f1:5592"
    }

    XCTAssertEqual(resolved?.compositeID, "f1:5789")
  }

  func testPreferredWidgetFallbackTeamIgnoresRecentsWhenNoFavorites() {
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = []
    settings.recentTeamCompositeIDs = ["f1:5592"]

    let resolved = TeamCatalog.preferredWidgetFallbackTeam(settings: settings) { _ in
      true
    }

    XCTAssertNil(resolved)
  }

  func testWidgetTeamSelectionUsesConfiguredTeamWhenPresent() {
    let resolved = TeamCatalog.resolveWidgetSelectionTeam(
      configuredCompositeID: "f1:5789",
      settings: .default
    )

    XCTAssertEqual(resolved.compositeID, "f1:5789")
  }

  func testWidgetTeamSelectionFallsBackToFavoriteBeforeRecent() {
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = ["f1:5789"]
    settings.recentTeamCompositeIDs = ["f1:5592"]

    let resolved = TeamCatalog.resolveWidgetSelectionTeam(
      configuredCompositeID: nil,
      settings: settings
    )

    XCTAssertEqual(resolved.compositeID, "f1:5789")
  }

  func testWidgetTeamSelectionUsesFavoriteWhenConfiguredIDIsUnknown() {
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = ["f1:5789"]
    settings.recentTeamCompositeIDs = ["f1:5592"]

    let resolved = TeamCatalog.resolveWidgetSelectionTeam(
      configuredCompositeID: "f1:999999",
      settings: settings
    )

    XCTAssertEqual(resolved.compositeID, "f1:5789")
  }

  func testWidgetConfigurationTeamsDoNotCollapseToRecentOnly() {
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = []
    settings.recentTeamCompositeIDs = ["f1:5592"]

    let configurationTeams = TeamCatalog.widgetConfigurationTeams(settings: settings)

    XCTAssertTrue(configurationTeams.isEmpty)
  }

  func testWidgetConfigurationTeamsIncludeOnlyFavoritesInOrder() {
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = ["f1:5789", "nhl:23", "f1:5789"]
    settings.recentTeamCompositeIDs = ["f1:5592"]

    let configurationTeams = TeamCatalog.widgetConfigurationTeams(settings: settings)

    XCTAssertEqual(configurationTeams.map(\.compositeID), ["f1:5789", "nhl:23"])
  }

  func testWidgetPickerTeamsFallsBackToFullCatalogWhenFavoritesEmpty() {
    let settings = AppSettings.default
    XCTAssertTrue(TeamCatalog.widgetConfigurationTeams(settings: settings).isEmpty)

    let pickerTeams = TeamCatalog.widgetPickerTeams(settings: settings)

    XCTAssertFalse(pickerTeams.isEmpty)
    XCTAssertEqual(Set(pickerTeams.map(\.compositeID)), Set(TeamCatalog.teams.map(\.compositeID)))
    XCTAssertTrue(pickerTeams.contains { $0.compositeID == TeamCatalog.defaultTeamCompositeID })
  }

  func testWidgetPickerTeamsPinsFavoritesWhenPresent() {
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = ["nhl:23", "f1:5789"]
    settings.recentTeamCompositeIDs = ["f1:5592"]

    let pickerTeams = TeamCatalog.widgetPickerTeams(settings: settings)

    XCTAssertGreaterThanOrEqual(pickerTeams.count, 3)
    XCTAssertEqual(
      pickerTeams.prefix(2).map(\.compositeID),
      ["nhl:23", "f1:5789"],
      "Favorites should lead the picker; remaining catalog entries follow."
    )
  }

  func testRegressionNewWidgetTeamPickerMatchesPersistedFavoritesNotRecents() throws {
    XCTAssertNotNil(
      ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"],
      "Tests should use the XCTest sandboxed settings store path."
    )

    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = ["nhl:23", "f1:5789"]
    settings.recentTeamCompositeIDs = ["f1:5592"]

    let store = AppSettingsStore(cloudSyncEnabled: false)
    store.save(settings)
    let loaded = store.load()

    XCTAssertEqual(
      TeamCatalog.widgetConfigurationTeams(settings: loaded).map(\.compositeID),
      ["nhl:23", "f1:5789"],
      "Adding a widget should offer the same ordered favorites the app persisted, not recents-only noise."
    )
  }

  func testWidgetShowsCatchUpMessageWhenGamesExistButNoPreviousOrUpcomingRows() {
    guard let team = TeamCatalog.team(withCompositeID: "nhl:23") else {
      XCTFail("Expected TeamCatalog entry for Washington Capitals.")
      return
    }

    let now = Date()
    let staleScheduledPast = makeGame(
      id: "orphan",
      services: ["ESPN+"],
      startTime: now.addingTimeInterval(-3600),
      status: .scheduled
    )

    let state = HomeTeamWidgetContentState(
      referenceDate: now,
      snapshot: ScheduleSnapshot(games: [staleScheduledPast], lastUpdated: now, errorMessage: nil, teamSummary: nil),
      settings: .default,
      team: team,
      isTeamSelectionConfigured: true
    )

    XCTAssertEqual(state.widgetEmptyStateMessage.title, "Schedule is still catching up")
    XCTAssertTrue(state.widgetEmptyStateMessage.detail.contains("Open HomeTeam"))
  }

  func testWidgetGlobalEmptyExplainsStreamingFiltersWhenUpcomingWouldBeHidden() {
    guard let team = TeamCatalog.team(withCompositeID: "nhl:23") else {
      XCTFail("Expected TeamCatalog entry for Washington Capitals.")
      return
    }

    let now = Date()
    let upcomingGame = makeGame(
      id: "g1",
      services: ["ESPN+"],
      startTime: now.addingTimeInterval(86_400),
      status: .scheduled
    )

    var settings = AppSettings.default
    settings.selectedStreamingServices = ["Hulu"]

    let state = HomeTeamWidgetContentState(
      referenceDate: now,
      snapshot: ScheduleSnapshot(games: [upcomingGame], lastUpdated: now, errorMessage: nil, teamSummary: nil),
      settings: settings,
      team: team,
      isTeamSelectionConfigured: true
    )

    XCTAssertTrue(state.upcomingHiddenByStreamingFilter)
    XCTAssertEqual(state.widgetEmptyStateMessage.title, "Upcoming hidden by streaming filters")
    XCTAssertTrue(state.widgetEmptyStateMessage.detail.contains("HomeTeam Settings"))
  }

  func testWidgetPreviousRowStillShowsWhenUpcomingFilteredByStreaming() {
    guard let team = TeamCatalog.team(withCompositeID: "nhl:23") else {
      XCTFail("Expected TeamCatalog entry for Washington Capitals.")
      return
    }

    let now = Date()
    let finalGame = makeGame(
      id: "fin",
      services: ["ESPN+"],
      startTime: now.addingTimeInterval(-86_400),
      status: .final,
      homeScore: 3,
      awayScore: 2
    )
    let upcomingGame = makeGame(
      id: "up",
      services: ["ESPN+"],
      startTime: now.addingTimeInterval(86_400),
      status: .scheduled
    )

    var settings = AppSettings.default
    settings.selectedStreamingServices = ["Hulu"]

    let state = HomeTeamWidgetContentState(
      referenceDate: now,
      snapshot: ScheduleSnapshot(games: [finalGame, upcomingGame], lastUpdated: now, errorMessage: nil, teamSummary: nil),
      settings: settings,
      team: team,
      isTeamSelectionConfigured: true
    )

    XCTAssertTrue(state.upcomingHiddenByStreamingFilter)
    XCTAssertFalse(state.snapshot.games.previousGames(now: now, limit: 3).isEmpty)
    XCTAssertTrue(
      state.snapshot.games.upcomingGames(now: now, limit: 3, selectedServiceLookup: settings.selectedServiceLookup)
        .isEmpty
    )
  }

  func testPrioritizedWidgetConfigurationTeamsUsesFavoriteThenRecentOrder() {
    guard
      let bearman = TeamCatalog.team(withCompositeID: "f1:5789"),
      let albon = TeamCatalog.team(withCompositeID: "f1:5592"),
      let capitals = TeamCatalog.team(withCompositeID: "nhl:23")
    else {
      XCTFail("Expected catalog entries for Bearman, Albon, and Capitals.")
      return
    }

    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = ["f1:5789"]
    settings.recentTeamCompositeIDs = ["f1:5592"]

    let sorted = TeamCatalog.prioritizedWidgetConfigurationTeams(
      from: [capitals, albon, bearman],
      settings: settings
    )

    XCTAssertEqual(sorted.map(\.compositeID), ["f1:5789", "f1:5592", "nhl:23"])
  }

  func testWidgetUnconfiguredStateWithFavoritesShowsEditGuidance() {
    guard let team = TeamCatalog.team(withCompositeID: "nhl:23") else {
      XCTFail("Expected TeamCatalog entry for Washington Capitals.")
      return
    }

    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = ["f1:5789"]

    let state = HomeTeamWidgetContentState(
      referenceDate: Date(),
      snapshot: ScheduleSnapshot(games: [], lastUpdated: Date(), errorMessage: nil, teamSummary: nil),
      settings: settings,
      team: team,
      isTeamSelectionConfigured: false
    )

    XCTAssertEqual(state.widgetTitleText, "Choose HomeTeam")
    XCTAssertEqual(state.widgetEmptyStateMessage.title, "Widget not configured")
    XCTAssertEqual(state.widgetEmptyStateMessage.detail, "Right-click this widget and choose Edit \"HomeTeam\".")
  }

  func testWidgetUnconfiguredStateWithoutFavoritesPromptsToAddFavorites() {
    guard let team = TeamCatalog.team(withCompositeID: "nhl:23") else {
      XCTFail("Expected TeamCatalog entry for Washington Capitals.")
      return
    }

    let state = HomeTeamWidgetContentState(
      referenceDate: Date(),
      snapshot: ScheduleSnapshot(games: [], lastUpdated: Date(), errorMessage: nil, teamSummary: nil),
      settings: .default,
      team: team,
      isTeamSelectionConfigured: false
    )

    XCTAssertEqual(state.widgetTitleText, "Choose HomeTeam")
    XCTAssertEqual(state.widgetEmptyStateMessage.title, "Add favorites in HomeTeam")
    XCTAssertEqual(
      state.widgetEmptyStateMessage.detail,
      "Then right-click this widget and choose Edit \"HomeTeam\"."
    )
  }

  func testWidgetConfiguredStateUsesSnapshotErrorForEmptyStateDetail() {
    guard let team = TeamCatalog.team(withCompositeID: "f1:5789") else {
      XCTFail("Expected TeamCatalog entry for O. Bearman - Haas.")
      return
    }

    let state = HomeTeamWidgetContentState(
      referenceDate: Date(),
      snapshot: ScheduleSnapshot(
        games: [],
        lastUpdated: Date(),
        errorMessage: "Refresh failed (network timeout). Showing last available data.",
        teamSummary: nil
      ),
      settings: .default,
      team: team,
      isTeamSelectionConfigured: true
    )

    XCTAssertEqual(state.widgetTitleText, "O. Bearman - Haas")
    XCTAssertEqual(state.widgetEmptyStateMessage.title, "Unable to load games")
    XCTAssertEqual(
      state.widgetEmptyStateMessage.detail,
      "Refresh failed (network timeout). Showing last available data."
    )
  }

  func testLegacyRecentsOnlySettingsDoNotForceAlbonWidgetSelection() throws {
    let legacyLikeJSON = """
    {
      "selectedStreamingServices": ["Hulu"],
      "zipCode": "",
      "city": null,
      "state": null,
      "notifications": {
        "gameStartReminders": true,
        "finalScores": true
      },
      "recentTeamCompositeIDs": ["f1:5592"],
      "hideDuringOffseasonTeamCompositeIDs": []
    }
    """

    let decoded = try JSONDecoder().decode(
      AppSettings.self,
      from: Data(legacyLikeJSON.utf8)
    )

    XCTAssertEqual(decoded.favoriteTeamCompositeIDs, [])
    XCTAssertEqual(decoded.recentTeamCompositeIDs, ["f1:5592"])

    // Favorites remain empty, so widget configuration should not be locked to recents.
    let selectableFavorites = decoded.favoriteTeamCompositeIDs.compactMap(TeamCatalog.team(withCompositeID:))
    XCTAssertTrue(selectableFavorites.isEmpty)

    let resolved = TeamCatalog.resolveWidgetSelectionTeam(
      configuredCompositeID: nil,
      settings: decoded
    )
    XCTAssertEqual(resolved.compositeID, TeamCatalog.defaultTeamCompositeID)
  }

  func testAppSettingsSanitizeMigratesLegacyFavoriteIdentifiers() {
    let settings = AppSettings(
      selectedStreamingServices: [],
      zipCode: "",
      city: nil,
      state: nil,
      notifications: .default,
      favoriteTeamCompositeIDs: ["f1_5789", "mgp-mmarquez", "unknown-id"],
      hideDuringOffseasonTeamCompositeIDs: [],
      recentTeamCompositeIDs: []
    )

    XCTAssertEqual(settings.favoriteTeamCompositeIDs, ["f1:5789", "motogp:mgp-mmarquez"])
  }

  private func makeGame(
    id: String,
    services: [String],
    startTime: Date = Date(),
    status: GameStatus = .scheduled,
    sport: SupportedSport? = .nhl,
    homeTeam: String = "Home",
    awayTeam: String = "Away",
    homeScore: Int? = nil,
    awayScore: Int? = nil
  ) -> HomeTeamGame {
    HomeTeamGame(
      id: id,
      startTimeUTC: startTime,
      venue: "Test Venue",
      status: status,
      statusDetail: "",
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      homeAbbrev: "HME",
      awayAbbrev: "AWY",
      homeLogoURL: nil,
      awayLogoURL: nil,
      homeScore: homeScore,
      awayScore: awayScore,
      homeRecord: nil,
      awayRecord: nil,
      streamingServices: services,
      sport: sport,
      racingResults: nil
    )
  }

  func testScheduleSnapshotMergePreservesCachedGamesOnEmptySuccess() {
    let cachedGame = makeGame(id: "g1", services: [])
    let cached = ScheduleSnapshot(
      games: [cachedGame],
      lastUpdated: Date(timeIntervalSince1970: 1_700_000_000),
      errorMessage: nil,
      teamSummary: nil
    )
    let fresh = ScheduleSnapshot(games: [], lastUpdated: Date(), errorMessage: nil, teamSummary: nil)
    let merged = fresh.mergingNondestructively(withExisting: cached)

    XCTAssertEqual(merged.games.map(\.id), ["g1"])
    XCTAssertEqual(merged.lastUpdated, cached.lastUpdated)
  }

  func testScheduleSnapshotMergeUsesFreshGamesWhenNonEmpty() {
    let cachedGame = makeGame(id: "old", services: [])
    let freshGame = makeGame(id: "new", services: [])
    let cached = ScheduleSnapshot(games: [cachedGame], lastUpdated: Date(), errorMessage: nil, teamSummary: nil)
    let fresh = ScheduleSnapshot(games: [freshGame], lastUpdated: Date(), errorMessage: nil, teamSummary: nil)
    let merged = fresh.mergingNondestructively(withExisting: cached)

    XCTAssertEqual(merged.games.map(\.id), ["new"])
  }

  func testScheduleSnapshotMergeDoesNotRunWhenErrorPresent() {
    let cachedGame = makeGame(id: "g1", services: [])
    let cached = ScheduleSnapshot(games: [cachedGame], lastUpdated: Date(), errorMessage: nil, teamSummary: nil)
    let fresh = ScheduleSnapshot(games: [], lastUpdated: Date(), errorMessage: "failed", teamSummary: nil)
    let merged = fresh.mergingNondestructively(withExisting: cached)

    XCTAssertTrue(merged.games.isEmpty)
    XCTAssertEqual(merged.errorMessage, "failed")
  }

  func testWidgetEmptyConfiguredStateMentionsEditHomeTeam() {
    guard let team = TeamCatalog.team(withCompositeID: "nhl:23") else {
      XCTFail("Expected TeamCatalog entry for Washington Capitals.")
      return
    }

    let state = HomeTeamWidgetContentState(
      referenceDate: Date(),
      snapshot: ScheduleSnapshot(games: [], lastUpdated: Date(), errorMessage: nil, teamSummary: nil),
      settings: .default,
      team: team,
      isTeamSelectionConfigured: true
    )

    XCTAssertEqual(state.widgetEmptyStateMessage.title, "No games available")
    XCTAssertTrue(
      state.widgetEmptyStateMessage.detail.contains("Edit \"HomeTeam\""),
      "Expected edit-widget guidance in empty-state copy: \(state.widgetEmptyStateMessage.detail)"
    )
  }
}

final class WidgetSnapshotArtifactTests: XCTestCase {
  private let largeCanvasSize = CGSize(width: 364, height: 382)
  private let requiredSports: [SupportedSport] = [.nhl, .mlb, .nfl, .nba, .mls, .premierLeague, .f1, .motogp]

  /// Live ESPN/API + snapshot generation; opt-in so `xcodebuild test` without env vars stays deterministic.
  private var shouldRunLiveNetworkQA: Bool {
    ProcessInfo.processInfo.environment["HOMETEAM_RUN_NETWORK_TESTS"] == "1"
  }

  private var snapshotMode: SnapshotMode {
    let explicit = ProcessInfo.processInfo.environment["HOMETEAM_QA_WIDGET_SNAPSHOT_MODE"]?
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    switch explicit {
    case "coverage", "all", "all-sports":
      return .coverage
    case "prod", "production", "parity":
      return .prodParity
    default:
      return .coverage
    }
  }

  @MainActor
  func testGenerateWidgetSnapshotArtifacts() async throws {
    guard shouldRunLiveNetworkQA else {
      throw XCTSkip(
        "Widget snapshot QA requires live network. Set HOMETEAM_RUN_NETWORK_TESTS=1 or run macos/scripts/capture_widget_screenshot.sh."
      )
    }

    RuntimeIssueCenter.clear()
    let outputDirectory = try preparedOutputDirectory()
    let variants = try await snapshotVariantsFromLiveData(mode: snapshotMode)
    try await assertLogoCacheIsReady(for: variants)
    try assertNoRuntimeIssues(context: "Widget snapshot artifact generation")
    var manifestEntries: [SnapshotManifestEntry] = []

    for variant in variants {
      let image = try renderSnapshot(for: variant.state, canvasSize: variant.canvasSize)
      let fileURL = outputDirectory.appendingPathComponent(variant.fileName)
      try writePNG(image: image, to: fileURL)

      let entry = SnapshotManifestEntry(
        fileName: variant.fileName,
        width: Int(variant.canvasSize.width),
        height: Int(variant.canvasSize.height),
        sha256: sha256Hex(ofFile: fileURL)
      )
      manifestEntries.append(entry)

      let attachment = XCTAttachment(contentsOfFile: fileURL)
      attachment.name = variant.fileName
      attachment.lifetime = .keepAlways
      add(attachment)
    }

    let manifest = SnapshotManifest(
      generatedAtUTC: Self.iso8601String(from: Date()),
      files: manifestEntries
    )
    let manifestData = try JSONEncoder().encode(manifest)
    try manifestData.write(to: outputDirectory.appendingPathComponent("manifest.json"), options: .atomic)

    XCTAssertEqual(manifestEntries.count, variants.count, "Expected one manifest entry per generated snapshot.")
    switch snapshotMode {
    case .coverage:
      XCTAssertEqual(variants.count, requiredSports.count, "Expected one live snapshot variant per supported sport.")
    case .prodParity:
      XCTAssertFalse(variants.isEmpty, "Expected at least one prod-parity widget snapshot.")
    }
  }

  private func assertLogoCacheIsReady(for variants: [SnapshotVariant]) async throws {
    let allGames = variants.flatMap { $0.state.snapshot.games }
    XCTAssertFalse(allGames.isEmpty, "Live snapshot QA returned no games across all sports.")

    let teamLogoStore = TeamLogoStore()
    RuntimeIssueCenter.clear()
    await teamLogoStore.prefetchLogos(for: allGames)
    try assertNoRuntimeIssues(context: "Logo prefetch before snapshot render")

    for variant in variants where variant.sport == .f1 || variant.sport == .motogp {
      let displayedRacingLines = variant.state.snapshot.games
        .previousGames(now: variant.state.referenceDate, limit: 3)
        .flatMap { $0.racingResults ?? [] }

      XCTAssertFalse(
        displayedRacingLines.isEmpty,
        "Live \(variant.sport.displayName) snapshot has no completed racing result rows; cannot validate logos."
      )

      let missingLogoURLDrivers = displayedRacingLines
        .filter { ($0.teamLogoURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .map(\.driver)

      XCTAssertTrue(
        missingLogoURLDrivers.isEmpty,
        "\(variant.sport.displayName) result rows are missing teamLogoURL values: \(missingLogoURLDrivers.joined(separator: ", "))"
      )

      let missingCacheEntries = displayedRacingLines.compactMap { line -> String? in
        guard let logoURL = line.teamLogoURL else {
          return "\(line.driver):<missing-url>"
        }
        return teamLogoStore.cachedImage(for: logoURL, teamAbbrev: line.teamAbbrev, sport: variant.sport) == nil
          ? "\(line.teamAbbrev):\(logoURL)"
          : nil
      }

      XCTAssertTrue(
        missingCacheEntries.isEmpty,
        "\(variant.sport.displayName) widget logos failed to cache before render: \(missingCacheEntries.joined(separator: ", "))"
      )
    }
  }

  private func snapshotVariantsFromLiveData(mode: SnapshotMode) async throws -> [SnapshotVariant] {
    let repository = ScheduleRepository()
    var variants: [SnapshotVariant] = []
    let teams: [TeamDefinition]

    switch mode {
    case .coverage:
      teams = try requiredSports.map(representativeTeam(for:))
    case .prodParity:
      teams = prodParityTeamsFromSettings()
    }

    for (index, team) in teams.enumerated() {
      RuntimeIssueCenter.clear()
      let snapshot = await repository.refresh(for: team)
      if let errorMessage = snapshot.errorMessage {
        throw SnapshotError.liveDataRefreshFailed("\(team.displayName): \(errorMessage)")
      }
      try assertNoRuntimeIssues(context: "\(team.displayName) refresh")

      let settings = AppSettings(
        selectedStreamingServices: [],
        zipCode: "00000",
        city: nil,
        state: nil,
        notifications: .default,
        favoriteTeamCompositeIDs: [team.compositeID],
        hideDuringOffseasonTeamCompositeIDs: [],
        recentTeamCompositeIDs: [team.compositeID]
      )

      let state = HomeTeamWidgetContentState(
        referenceDate: Date(),
        snapshot: snapshot,
        settings: settings,
        team: team,
        isTeamSelectionConfigured: true
      )

      variants.append(
        SnapshotVariant(
          sport: team.sport,
          fileName: snapshotFileName(for: team, mode: mode, index: index),
          canvasSize: largeCanvasSize,
          state: state
        )
      )
    }

    return variants
  }

  private func prodParityTeamsFromSettings() -> [TeamDefinition] {
    if
      let overrideCompositeID = ProcessInfo.processInfo.environment["HOMETEAM_QA_TEAM_COMPOSITE_ID"]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !overrideCompositeID.isEmpty,
      let overrideTeam = TeamCatalog.team(withCompositeID: overrideCompositeID)
    {
      return [overrideTeam]
    }

    let settings = AppSettingsStore().load()
    let favoriteTeams = dedupeIDs(settings.favoriteTeamCompositeIDs).compactMap(TeamCatalog.team(withCompositeID:))
    if !favoriteTeams.isEmpty {
      return favoriteTeams
    }

    if let fallback = TeamCatalog.preferredWidgetFallbackTeam(settings: settings) {
      return [fallback]
    }

    return [TeamCatalog.defaultTeam()]
  }

  private func snapshotFileName(for team: TeamDefinition, mode: SnapshotMode, index: Int) -> String {
    switch mode {
    case .coverage:
      return "widget-\(sportFileToken(for: team.sport))-large.png"
    case .prodParity:
      let sportToken = sportFileToken(for: team.sport)
      let teamToken = team.compositeID
        .lowercased()
        .replacingOccurrences(of: ":", with: "_")
        .replacingOccurrences(of: "/", with: "_")
      return "widget-prod-\(index + 1)-\(sportToken)-\(teamToken)-large.png"
    }
  }

  private func dedupeIDs(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var ordered: [String] = []
    for value in values {
      let normalized = value
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
      guard !normalized.isEmpty else {
        continue
      }
      if seen.insert(normalized).inserted {
        ordered.append(value)
      }
    }
    return ordered
  }

  private func assertNoRuntimeIssues(context: String) throws {
    let issues = RuntimeIssueCenter.allMessages()
    guard issues.isEmpty else {
      throw SnapshotError.runtimeIssuesDetected(context: context, messages: issues)
    }
  }

  private func representativeTeam(for sport: SupportedSport) throws -> TeamDefinition {
    let preferredCompositeIDs: [SupportedSport: String] = [
      .nhl: "nhl:23",
      .mlb: "mlb:20",
      .nfl: "nfl:28",
      .nba: "nba:27",
      .mls: "mls:193",
      .premierLeague: "premierLeague:359",
      .f1: "f1:5789",
      .motogp: "motogp:mgp-mmarquez",
    ]

    if
      let preferredCompositeID = preferredCompositeIDs[sport],
      let team = TeamCatalog.team(withCompositeID: preferredCompositeID)
    {
      return team
    }

    if let fallback = TeamCatalog.teams(for: sport).first {
      return fallback
    }

    throw SnapshotError.missingTeamCatalogEntry(sport.displayName)
  }

  private func sportFileToken(for sport: SupportedSport) -> String {
    switch sport {
    case .premierLeague:
      return "premierleague"
    default:
      return sport.rawValue.lowercased()
    }
  }

  private func preparedOutputDirectory() throws -> URL {
    let fileManager = FileManager.default
    if let explicitDirectory = ProcessInfo.processInfo.environment["HOMETEAM_WIDGET_ARTIFACT_DIR"] {
      let explicitURL = URL(fileURLWithPath: explicitDirectory, isDirectory: true)
      try fileManager.createDirectory(at: explicitURL, withIntermediateDirectories: true)
      return explicitURL
    }

    let fallbackDirectory = fileManager.temporaryDirectory
      .appendingPathComponent("HomeTeamWidgetSnapshots", isDirectory: true)
      .appendingPathComponent(Self.iso8601PathComponent(from: Date()), isDirectory: true)
    try fileManager.createDirectory(at: fallbackDirectory, withIntermediateDirectories: true)
    return fallbackDirectory
  }

  @MainActor
  private func renderSnapshot(
    for state: HomeTeamWidgetContentState,
    canvasSize: CGSize
  ) throws -> NSImage {
    let content = WidgetRenderHost(state: state)
      .frame(width: canvasSize.width, height: canvasSize.height)
      .background(Color(red: 0.04, green: 0.05, blue: 0.07))
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .stroke(Color.white.opacity(0.2), lineWidth: 1)
      )

    let renderer = ImageRenderer(content: content)
    renderer.scale = 2

    guard let image = renderer.nsImage else {
      throw SnapshotError.renderFailed
    }

    return flattenedImage(image, backgroundColor: NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.07, alpha: 1))
  }

  private func flattenedImage(_ image: NSImage, backgroundColor: NSColor) -> NSImage {
    let rect = NSRect(origin: .zero, size: image.size)
    let flattened = NSImage(size: image.size)
    flattened.lockFocus()
    backgroundColor.setFill()
    NSBezierPath(rect: rect).fill()
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    flattened.unlockFocus()
    return flattened
  }

  private func writePNG(image: NSImage, to destinationURL: URL) throws {
    guard
      let tiffData = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:])
    else {
      throw SnapshotError.encodingFailed
    }

    try pngData.write(to: destinationURL, options: .atomic)
  }

  private func sha256Hex(ofFile fileURL: URL) -> String {
    guard let data = try? Data(contentsOf: fileURL) else {
      return "unavailable"
    }
    let digest = SHA256.hash(data: data)
    return digest.map { String(format: "%02x", $0) }.joined()
  }

  private static func iso8601String(from date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.string(from: date)
  }

  private static func iso8601PathComponent(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyyMMdd_HHmmss"
    return formatter.string(from: date)
  }
}

private struct WidgetRenderHost: View {
  let state: HomeTeamWidgetContentState

  var body: some View {
    HomeTeamWidgetContentView(state: state)
      .containerBackground(HomeTeamWidgetBackground.gradient, for: .widget)
  }
}

private struct SnapshotVariant {
  let sport: SupportedSport
  let fileName: String
  let canvasSize: CGSize
  let state: HomeTeamWidgetContentState
}

private enum SnapshotMode {
  case coverage
  case prodParity
}

private struct SnapshotManifest: Codable {
  let generatedAtUTC: String
  let files: [SnapshotManifestEntry]
}

private struct SnapshotManifestEntry: Codable {
  let fileName: String
  let width: Int
  let height: Int
  let sha256: String
}

private enum SnapshotError: LocalizedError {
  case renderFailed
  case encodingFailed
  case missingTeamCatalogEntry(String)
  case liveDataRefreshFailed(String)
  case runtimeIssuesDetected(context: String, messages: [String])

  var errorDescription: String? {
    switch self {
    case .renderFailed:
      return "Failed to render widget snapshot image."
    case .encodingFailed:
      return "Failed to encode widget snapshot PNG."
    case .missingTeamCatalogEntry(let sport):
      return "Missing TeamCatalog entry for \(sport)."
    case .liveDataRefreshFailed(let message):
      return "Live data refresh failed: \(message)"
    case .runtimeIssuesDetected(let context, let messages):
      let joined = messages.joined(separator: " | ")
      return "Runtime status issues detected during \(context): \(joined)"
    }
  }
}
