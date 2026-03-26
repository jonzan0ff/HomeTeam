import XCTest
@testable import HomeTeam

// MARK: - StreamingServiceMatcher

final class StreamingFilterTests: XCTestCase {

  func test_canonicalKey_espnPlus() {
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "ESPN+"), "espnplus")
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "espn+"), "espnplus")
  }

  func test_canonicalKey_appleTV() {
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "Apple TV+"), "appletvplus")
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "appletv+"), "appletvplus")
  }

  func test_canonicalKey_appleTV_withoutPlus() {
    // ESPN F1 API returns "Apple TV" (no +) — must still map to appletvplus
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "Apple TV"), "appletvplus")
  }

  func test_canonicalKey_primevideo() {
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "Amazon Prime Video"), "primevideo")
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "Prime Video"), "primevideo")
  }

  func test_canonicalKey_fs1_variants() {
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "FS1"), "fs1")
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "Fox Sports 1"), "fs1")
  }

  func test_canonicalKey_fs2_variants() {
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "FS2"), "fs2")
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "Fox Sports 2"), "fs2")
  }

  func test_canonicalKey_fox() {
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "Fox"), "fox")
  }

  func test_canonicalKey_max_catchesTNT() {
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "TNT"), "max")
  }

  func test_canonicalKey_max_catchesHBO() {
    // ESPN returns "HBO" as a standalone network name for some NHL/NBA games
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "HBO"), "max")
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "HBO Max"), "max")
  }

  func test_canonicalKey_max_catchesTNTSlashHBO() {
    // ESPN returns compound "TNT/HBO" for Washington Capitals and other NHL/NBA games
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "TNT/HBO"), "max")
  }

  func test_canonicalKey_max_catchesTruTV() {
    // TruTV carries overflow Max/TNT sports content
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "TruTV"), "max")
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "truTV"), "max")
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "TrueTV"), "max")
  }

  func test_isMatch_max_selected_catchesTNTSlashHBO() {
    // If user selects Max, "TNT/HBO" game must pass the streaming filter
    let selected: Set<String> = ["max"]
    XCTAssertTrue(StreamingServiceMatcher.isMatch(rawName: "TNT/HBO", selectedKeys: selected),
      "TNT/HBO compound network name must match when user has Max selected")
  }

  func test_canonicalKey_unknown_returnsNil() {
    XCTAssertNil(StreamingServiceMatcher.canonicalKey(for: "FakeNetwork123"))
  }

  func test_isMatch_returnsTrue_whenKeyInSet() {
    let selected: Set<String> = ["espnplus", "netflix"]
    XCTAssertTrue(StreamingServiceMatcher.isMatch(rawName: "ESPN+", selectedKeys: selected))
    XCTAssertTrue(StreamingServiceMatcher.isMatch(rawName: "Netflix", selectedKeys: selected))
  }

  func test_isMatch_returnsFalse_whenKeyNotInSet() {
    let selected: Set<String> = ["espnplus"]
    XCTAssertFalse(StreamingServiceMatcher.isMatch(rawName: "Peacock", selectedKeys: selected))
  }

  func test_isMatch_returnsFalse_whenNoServicesSelected() {
    XCTAssertFalse(StreamingServiceMatcher.isMatch(rawName: "ESPN+", selectedKeys: []))
  }
}

// MARK: - MotoGPCalendarParser

final class MotoGPCalendarParserTests: XCTestCase {

  // MARK: Race date selection

  func test_usesDateEnd_asRaceDay() throws {
    // date_start = Thursday practice start, date_end = Sunday race day
    let json = motogpJSON(dateStart: "2026-03-26", dateEnd: "2026-03-29")
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertEqual(games.count, 1)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let weekday = cal.component(.weekday, from: games[0].scheduledAt)
    XCTAssertEqual(weekday, 1, "Race date should be Sunday (date_end=29th), not Thursday (date_start=26th)")
  }

  func test_fallsBackToDateStart_whenNoDateEnd() throws {
    let json = motogpJSON(dateStart: "2026-03-26", dateEnd: nil)
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertEqual(games.count, 1)
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let weekday = cal.component(.weekday, from: games[0].scheduledAt)
    XCTAssertEqual(weekday, 5, "Should fall back to date_start (Thursday = weekday 5)")
  }

  // MARK: Broadcast networks

  func test_hardcodesFS1_broadcast() throws {
    let json = motogpJSON(dateStart: "2026-03-26", dateEnd: "2026-03-29")
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertEqual(games[0].broadcastNetworks, ["FS1"],
      "MotoGP API returns no broadcast data — US rights are Fox/FS1, must be hardcoded")
  }

  func test_fs1_matchesStreamingFilter() throws {
    let json = motogpJSON(dateStart: "2026-03-26", dateEnd: "2026-03-29")
    let games = try MotoGPCalendarParser.parse(json)
    let passes = games[0].broadcastNetworks.contains {
      StreamingServiceMatcher.isMatch(rawName: $0, selectedKeys: ["fs1"])
    }
    XCTAssertTrue(passes, "MotoGP game with FS1 broadcast should pass filter when FS1 is selected")
  }

  // MARK: Name normalization

  func test_grandPrix_shortenedToGP() throws {
    let json = motogpJSON(name: "Grand Prix of Spain", dateStart: "2026-03-26")
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertFalse(games[0].homeTeamName.localizedCaseInsensitiveContains("grand prix"),
      "\"Grand Prix\" should be shortened to \"GP\"")
    XCTAssertTrue(games[0].homeTeamName.contains("GP"))
  }

  func test_sponsoredName_fallback() throws {
    let json = motogpJSONWithSponsoredName(sponsoredName: "Qatar Airways Grand Prix of Spain",
                                           dateStart: "2026-03-26")
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertFalse(games[0].homeTeamName.localizedCaseInsensitiveContains("grand prix"))
    XCTAssertTrue(games[0].homeTeamName.contains("GP"))
  }

  // MARK: Test event filtering

  func test_filtersOutTestEvents() throws {
    let json = motogpJSON(dateStart: "2026-02-10", isTest: true)
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertEqual(games.count, 0, "Pre-season test events (test: true) should be excluded")
  }

  func test_includesNonTestEvents() throws {
    let json = motogpJSON(dateStart: "2026-03-26")
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertEqual(games.count, 1)
  }

  // MARK: Status mapping

  func test_status_finished_mapsFinal() throws {
    let json = motogpJSON(dateStart: "2026-03-29", status: "FINISHED")
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertEqual(games[0].status, .final)
  }

  func test_status_inProgress_mapsLive() throws {
    let json = motogpJSON(dateStart: "2026-03-29", status: "IN-PROGRESS")
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertEqual(games[0].status, .live)
  }

  func test_status_nil_mapsScheduled() throws {
    let json = motogpJSON(dateStart: "2026-03-29", status: nil)
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertEqual(games[0].status, .scheduled)
  }

  // MARK: - Helpers

  private func motogpJSON(
    id: String = "evt-001",
    name: String? = "Grand Prix of Spain",
    dateStart: String,
    dateEnd: String? = nil,
    status: String? = nil,
    isTest: Bool = false
  ) -> Data {
    var fields: [String] = [
      #""id": "\#(id)""#,
      #""date_start": "\#(dateStart)""#,
      #""test": \#(isTest)"#
    ]
    if let name { fields.append(#""name": "\#(name)""#) }
    if let dateEnd { fields.append(#""date_end": "\#(dateEnd)""#) }
    if let status { fields.append(#""status": "\#(status)""#) }
    return ("[\n{\(fields.joined(separator: ",\n"))}\n]").data(using: .utf8)!
  }

  private func motogpJSONWithSponsoredName(sponsoredName: String, dateStart: String) -> Data {
    """
    [{"id":"evt-002","sponsored_name":"\(sponsoredName)","date_start":"\(dateStart)","test":false}]
    """.data(using: .utf8)!
  }
}

// MARK: - ESPNRacingParser

final class ESPNRacingParserTests: XCTestCase {

  // MARK: Race competition selection

  func test_usesTypeId3_asRaceCompetition() throws {
    // Event has practice (1), qualifying (2), and race (3) — date must come from race
    let json = espnJSON(competitions: [
      comp(typeId: 1, date: "2026-03-27T02:00Z"),
      comp(typeId: 2, date: "2026-03-28T06:00Z"),
      comp(typeId: 3, date: "2026-03-29T05:00Z", broadcasts: ["Apple TV"])
    ])
    let games = try ESPNRacingParser.parse(json, sport: .f1)
    XCTAssertEqual(games.count, 1)
    let day = Calendar(identifier: .gregorian).component(.day, from: games[0].scheduledAt)
    XCTAssertEqual(day, 29, "Should use race day (29th), not practice (27th) or qualifying (28th)")
  }

  func test_fallsBackToLastCompetition_whenNoTypeId3() throws {
    let json = espnJSON(competitions: [
      comp(typeId: 1, date: "2026-03-27T02:00Z"),
      comp(typeId: 2, date: "2026-03-28T06:00Z")
    ])
    let games = try ESPNRacingParser.parse(json, sport: .f1)
    XCTAssertEqual(games.count, 1)
    let day = Calendar(identifier: .gregorian).component(.day, from: games[0].scheduledAt)
    XCTAssertEqual(day, 28, "Should fall back to last competition when no type_id 3")
  }

  // MARK: Broadcast extraction

  func test_extractsBroadcastNames_fromNamesArray() throws {
    // ESPN returns broadcasts[].names — NOT broadcasts[].media.shortName
    let json = espnJSON(competitions: [comp(typeId: 3, date: "2026-03-29T05:00Z", broadcasts: ["Apple TV"])])
    let games = try ESPNRacingParser.parse(json, sport: .f1)
    XCTAssertEqual(games[0].broadcastNetworks, ["Apple TV"])
  }

  func test_broadcastNames_emptyWhenNoBroadcasts() throws {
    let json = espnJSON(competitions: [comp(typeId: 3, date: "2026-03-29T05:00Z")])
    let games = try ESPNRacingParser.parse(json, sport: .f1)
    XCTAssertTrue(games[0].broadcastNetworks.isEmpty)
  }

  func test_appleTV_matchesStreamingFilter() throws {
    // F1 2026 is on Apple TV+ — "Apple TV" (no +) must map to appletvplus
    let json = espnJSON(competitions: [comp(typeId: 3, date: "2026-03-29T05:00Z", broadcasts: ["Apple TV"])])
    let games = try ESPNRacingParser.parse(json, sport: .f1)
    let passes = games[0].broadcastNetworks.contains {
      StreamingServiceMatcher.isMatch(rawName: $0, selectedKeys: ["appletvplus"])
    }
    XCTAssertTrue(passes, "\"Apple TV\" from ESPN must match appletvplus streaming filter")
  }

  // MARK: Name normalization

  func test_grandPrix_shortenedToGP() throws {
    let json = espnJSON(name: "Japanese Grand Prix",
                        competitions: [comp(typeId: 3, date: "2026-03-29T05:00Z")])
    let games = try ESPNRacingParser.parse(json, sport: .f1)
    XCTAssertEqual(games[0].homeTeamName, "Japanese GP")
  }

  func test_nonGrandPrixName_unchanged() throws {
    let json = espnJSON(name: "Monaco Race",
                        competitions: [comp(typeId: 3, date: "2026-05-25T13:00Z")])
    let games = try ESPNRacingParser.parse(json, sport: .f1)
    XCTAssertEqual(games[0].homeTeamName, "Monaco Race")
  }

  // MARK: Status mapping

  func test_status_pre_mapsScheduled() throws {
    let json = espnJSON(state: "pre", completed: false,
                        competitions: [comp(typeId: 3, date: "2026-03-29T05:00Z")])
    XCTAssertEqual(try ESPNRacingParser.parse(json, sport: .f1)[0].status, .scheduled)
  }

  func test_status_in_mapsLive() throws {
    let json = espnJSON(state: "in", completed: false,
                        competitions: [comp(typeId: 3, date: "2026-03-29T05:00Z")])
    XCTAssertEqual(try ESPNRacingParser.parse(json, sport: .f1)[0].status, .live)
  }

  func test_status_post_completed_mapsFinal() throws {
    let json = espnJSON(state: "post", completed: true,
                        competitions: [comp(typeId: 3, date: "2026-03-29T05:00Z")])
    XCTAssertEqual(try ESPNRacingParser.parse(json, sport: .f1)[0].status, .final)
  }

  func test_sport_passedThrough() throws {
    let json = espnJSON(competitions: [comp(typeId: 3, date: "2026-03-29T05:00Z")])
    XCTAssertEqual(try ESPNRacingParser.parse(json, sport: .f1)[0].sport, .f1)
    XCTAssertEqual(try ESPNRacingParser.parse(json, sport: .motoGP)[0].sport, .motoGP)
  }

  // MARK: - Helpers

  private struct CompSpec {
    var typeId: Int?
    var date: String
    var broadcasts: [String]?
  }

  private func comp(typeId: Int? = nil, date: String, broadcasts: [String]? = nil) -> CompSpec {
    CompSpec(typeId: typeId, date: date, broadcasts: broadcasts)
  }

  private func espnJSON(
    name: String = "Japanese Grand Prix",
    state: String = "pre",
    completed: Bool = false,
    competitions: [CompSpec]
  ) -> Data {
    let compsJSON = competitions.map { c -> String in
      var fields = [#""date": "\#(c.date)""#]
      if let t = c.typeId { fields.append(#""type": {"id": "\#(t)"}"#) }
      if let b = c.broadcasts {
        let ns = b.map { #""\#($0)""# }.joined(separator: ", ")
        fields.append(#""broadcasts": [{"market": "national", "names": [\#(ns)]}]"#)
      }
      return "{\(fields.joined(separator: ", "))}"
    }.joined(separator: ", ")

    return """
    {"events": [{"id":"1","name":"\(name)","date":"\(competitions.first?.date ?? "2026-03-29T05:00Z")",
    "status":{"type":{"state":"\(state)","completed":\(completed),"detail":""}},
    "competitions":[\(compsJSON)]}]}
    """.data(using: .utf8)!
  }
}

// MARK: - Menu bar game filter

final class MenuBarGameFilterTests: XCTestCase {

  func test_excludesFinalGames() {
    let games = [
      makeGame(id: "1", status: .final,     scheduledAt: .distantPast),
      makeGame(id: "2", status: .scheduled, scheduledAt: Date().addingTimeInterval(3600)),
      makeGame(id: "3", status: .live,      scheduledAt: Date()),
    ]
    let result = menuBarGames(from: games, selectedStreamingKeys: [], hiddenCompositeIDs: [])
    XCTAssertEqual(result.map(\.id).sorted(), ["2", "3"],
      "Final/past games must not appear in the menu bar")
  }

  func test_excludesPostponedGames() {
    let games = [
      makeGame(id: "1", status: .postponed, scheduledAt: Date().addingTimeInterval(3600)),
      makeGame(id: "2", status: .scheduled, scheduledAt: Date().addingTimeInterval(7200)),
    ]
    let result = menuBarGames(from: games, selectedStreamingKeys: [], hiddenCompositeIDs: [])
    XCTAssertEqual(result.map(\.id), ["2"])
  }

  func test_sortedByScheduledAt() {
    let soon  = Date().addingTimeInterval(3600)
    let later = Date().addingTimeInterval(7200)
    let games = [
      makeGame(id: "later", status: .scheduled, scheduledAt: later),
      makeGame(id: "soon",  status: .scheduled, scheduledAt: soon),
    ]
    let result = menuBarGames(from: games, selectedStreamingKeys: [], hiddenCompositeIDs: [])
    XCTAssertEqual(result.map(\.id), ["soon", "later"])
  }

  func test_noStreamingSelection_showsAll() {
    let games = [makeGame(id: "1", status: .scheduled, broadcastNetworks: ["Regional Sports"])]
    let result = menuBarGames(from: games, selectedStreamingKeys: [], hiddenCompositeIDs: [])
    XCTAssertEqual(result.count, 1)
  }

  func test_streamingFilter_showsMatchingGame() {
    let games = [makeGame(id: "1", status: .scheduled, broadcastNetworks: ["ESPN+"])]
    let result = menuBarGames(from: games, selectedStreamingKeys: ["espnplus"], hiddenCompositeIDs: [])
    XCTAssertEqual(result.count, 1)
  }

  func test_streamingFilter_hidesNonMatchingGame() {
    let games = [makeGame(id: "1", status: .scheduled, broadcastNetworks: ["Peacock"])]
    let result = menuBarGames(from: games, selectedStreamingKeys: ["espnplus"], hiddenCompositeIDs: [])
    XCTAssertEqual(result.count, 0)
  }

  func test_streamingFilter_hidesGameWithNoRecognisedNetworks() {
    let games = [makeGame(id: "1", status: .scheduled, broadcastNetworks: ["SomeLocalChannel"])]
    let result = menuBarGames(from: games, selectedStreamingKeys: ["espnplus"], hiddenCompositeIDs: [])
    XCTAssertEqual(result.count, 0,
      "When streaming filter is active, games with no recognised networks are hidden")
  }

  // MARK: - Helpers

  private func makeGame(
    id: String,
    status: GameStatus,
    scheduledAt: Date = Date().addingTimeInterval(3600),
    broadcastNetworks: [String] = []
  ) -> HomeTeamGame {
    HomeTeamGame(
      id: id, sport: .nhl,
      homeTeamID: "1", awayTeamID: "2",
      homeTeamName: "Home", awayTeamName: "Away",
      homeTeamAbbrev: "HOM", awayTeamAbbrev: "AWY",
      homeScore: nil, awayScore: nil,
      homeRecord: nil, awayRecord: nil,
      scheduledAt: scheduledAt, status: status,
      statusDetail: nil, venueName: nil,
      broadcastNetworks: broadcastNetworks,
      isPlayoff: false, seriesInfo: nil, racingResults: nil
    )
  }
}

// MARK: - ScheduleSnapshot merge

final class ScheduleSnapshotTests: XCTestCase {

  func test_nonDestructiveMerge_preservesCachedGamesOnEmptyResponse() {
    let cached = ScheduleSnapshot(games: [makeGame(id: "1")], fetchedAt: Date(timeIntervalSinceNow: -60))
    let merged = cached.mergingNondestructively(with: .init(games: [], fetchedAt: Date()))
    XCTAssertEqual(merged.games.count, 1, "Empty refresh should not wipe cached games")
  }

  func test_nonDestructiveMerge_replacesWithNonEmptyResponse() {
    let cached = ScheduleSnapshot(games: [makeGame(id: "1")], fetchedAt: Date(timeIntervalSinceNow: -60))
    let fresh  = ScheduleSnapshot(games: [makeGame(id: "2"), makeGame(id: "3")], fetchedAt: Date())
    let merged = cached.mergingNondestructively(with: fresh)
    XCTAssertEqual(merged.games.count, 2)
    XCTAssertEqual(merged.games.map(\.id).sorted(), ["2", "3"])
  }

  private func makeGame(id: String) -> HomeTeamGame {
    HomeTeamGame(
      id: id, sport: .nhl,
      homeTeamID: "1", awayTeamID: "2",
      homeTeamName: "Home", awayTeamName: "Away",
      homeTeamAbbrev: "HOM", awayTeamAbbrev: "AWY",
      homeScore: nil, awayScore: nil,
      homeRecord: nil, awayRecord: nil,
      scheduledAt: Date(), status: .scheduled,
      statusDetail: nil, venueName: nil,
      broadcastNetworks: [], isPlayoff: false,
      seriesInfo: nil, racingResults: nil
    )
  }
}

// MARK: - compactRaceName

final class CompactRaceNameTests: XCTestCase {

  func test_australianGrandPrix() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: "Australian Grand Prix"), "Australian GP")
  }

  func test_sponsoredName_stripsPrefix() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: "Qatar Airways Australian Grand Prix"), "Australian GP")
  }

  func test_seriesPrefixAndYearSuffix_stripped() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: "Formula 1 Bahrain Grand Prix 2024"), "Bahrain GP")
  }

  func test_grandPrixOf_reordered() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: "Grand Prix of Monaco"), "Monaco GP")
  }

  func test_sponsoredGrandPrixOf_reordered() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: "MotoGP Grand Prix of Spain"), "Spain GP")
  }

  func test_heineken_stripsPrefix() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: "Heineken Dutch Grand Prix"), "Dutch GP")
  }

  func test_alreadyCompact_unchanged() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: "São Paulo GP"), "São Paulo GP")
  }

  func test_empty_returnsEmpty() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: ""), "")
  }

  // ESPNRacingParser.normalizedName() pre-converts "Grand Prix" → "GP" before
  // compactRaceName receives the string. These cases must be handled separately.
  func test_gpOf_reordered() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: "GP of Monaco"), "Monaco GP")
  }

  func test_gpOf_withSponsorPrefix_reordered() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: "MotoGP GP of Spain"), "Spain GP")
  }

  // Sponsor prefix stripping for already-compact "X GP" format (4+ words only).
  // 3-word inputs like "Aramco Japanese GP" are ambiguous — could be "2-word city + GP" (e.g. "São Paulo GP").
  // We only strip when there are 4+ words so multi-word city names are never corrupted.
  func test_sponsorPrefix_fourWords_alreadyGP_stripped() {
    XCTAssertEqual(GameFormatters.compactRaceName(from: "Qatar Airways Australian GP"), "Australian GP")
  }

  func test_sãoPaulo_unchanged() {
    // "São Paulo" is a two-word city — 3-word input must NOT be stripped to "Paulo GP"
    XCTAssertEqual(GameFormatters.compactRaceName(from: "São Paulo GP"), "São Paulo GP")
  }

  func test_unitedStates_returnsAmericasGP() {
    // US race is at Circuit of the Americas — hard-coded override
    XCTAssertEqual(GameFormatters.compactRaceName(from: "United States Grand Prix"), "Americas GP")
    XCTAssertEqual(GameFormatters.compactRaceName(from: "Formula 1 United States Grand Prix 2025"), "Americas GP")
  }
}

// MARK: - compactLiveStatus

final class CompactLiveStatusTests: XCTestCase {

  func test_nil_returnsLive() {
    XCTAssertEqual(GameFormatters.compactLiveStatus(from: nil), "LIVE")
  }

  func test_empty_returnsLive() {
    XCTAssertEqual(GameFormatters.compactLiveStatus(from: ""), "LIVE")
  }

  func test_periodWithTime() {
    XCTAssertEqual(GameFormatters.compactLiveStatus(from: "3rd Period - 14:32"), "3RD • 14:32")
  }

  func test_intermissionWithPeriod() {
    XCTAssertEqual(GameFormatters.compactLiveStatus(from: "End of the 2nd Period Intermission"), "2ND INT")
  }

  func test_intermissionAlone() {
    XCTAssertEqual(GameFormatters.compactLiveStatus(from: "Intermission"), "INT")
  }

  func test_overtime() {
    XCTAssertEqual(GameFormatters.compactLiveStatus(from: "Overtime"), "OT")
  }

  func test_shootout() {
    XCTAssertEqual(GameFormatters.compactLiveStatus(from: "Shootout"), "SO")
  }
}

// MARK: - AppGroupStore

final class AppGroupStoreTests: XCTestCase {

  func test_containerURL_isNonNil() throws {
    // App Group entitlements require a properly signed build — skip in unsigned CI.
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil,
      "App Group not available in unsigned CI build. Run locally with a signed build.")
    XCTAssertNotNil(AppGroupStore.containerURL,
      "App Group container must be accessible. Check entitlements and portal registration.")
  }

  func test_roundTrip_appSettings() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil,
      "App Group not available in unsigned CI build. Run locally with a signed build.")
    let original = AppSettings.default
    try AppGroupStore.write(original, to: "test_settings.json")
    let loaded = try AppGroupStore.read(AppSettings.self, from: "test_settings.json")
    XCTAssertEqual(original, loaded)
  }

  // MotoGP has no logos — logoFileURL must return nil regardless of App Group availability.
  func test_logoFileURL_motoGP_alwaysNil() {
    XCTAssertNil(AppGroupStore.logoFileURL(sport: .motoGP, espnTeamID: "motogp_ducati_lenovo"),
      "MotoGP has no logos; logoFileURL must always return nil for MotoGP")
  }

  // Empty espnTeamID must always return nil regardless of sport.
  func test_logoFileURL_emptyEspnTeamID_alwaysNil() {
    XCTAssertNil(AppGroupStore.logoFileURL(sport: .nhl, espnTeamID: ""))
    XCTAssertNil(AppGroupStore.logoFileURL(sport: .f1, espnTeamID: ""))
  }
}

// MARK: - TeamCatalog integrity
// These tests catch espnTeamID mismatches and missing catalog entries.
// The NHL bugs (WSH/SEA/VAN/SJ/WPG wrong IDs) and missing Kick Sauber
// would all have been caught by tests in this class.

final class TeamCatalogIntegrityTests: XCTestCase {

  // MARK: NHL known ESPN IDs (cross-referenced against ESPN CDN / download_logos.py)

  func test_nhl_washingtonCapitals_espnTeamID() {
    let team = TeamCatalog.all.first { $0.sport == .nhl && $0.name == "Capitals" }
    XCTAssertNotNil(team)
    XCTAssertEqual(team?.espnTeamID, "22",
      "Washington Capitals ESPN ID is 22, not 23. 23 = Seattle Kraken.")
  }

  func test_nhl_seattleKraken_espnTeamID() {
    let team = TeamCatalog.all.first { $0.sport == .nhl && $0.name == "Kraken" }
    XCTAssertNotNil(team)
    XCTAssertEqual(team?.espnTeamID, "23",
      "Seattle Kraken ESPN ID is 23.")
  }

  func test_nhl_vancouverCanucks_espnTeamID() {
    let team = TeamCatalog.all.first { $0.sport == .nhl && $0.name == "Canucks" }
    XCTAssertEqual(team?.espnTeamID, "18")
  }

  func test_nhl_sanJoseSharks_espnTeamID() {
    let team = TeamCatalog.all.first { $0.sport == .nhl && $0.name == "Sharks" }
    XCTAssertEqual(team?.espnTeamID, "28")
  }

  func test_nhl_winnipegJets_espnTeamID() {
    let team = TeamCatalog.all.first { $0.sport == .nhl && $0.name == "Jets" }
    XCTAssertEqual(team?.espnTeamID, "53")
  }

  // No two NHL teams should map to the same ESPN ID.
  func test_nhl_espnTeamIDs_areUnique() {
    let nhlIDs = TeamCatalog.all
      .filter { $0.sport == .nhl }
      .map { $0.espnTeamID }
    let unique = Set(nhlIDs)
    XCTAssertEqual(nhlIDs.count, unique.count,
      "Duplicate NHL espnTeamIDs found: \(nhlIDs.filter { id in nhlIDs.filter { $0 == id }.count > 1 })")
  }

  // MARK: F1 catalog coverage

  func test_f1_allEntries_haveNonEmptyEspnTeamID() {
    let bad = TeamCatalog.all.filter { $0.sport == .f1 && $0.espnTeamID.isEmpty }
    XCTAssertTrue(bad.isEmpty, "F1 entries with empty espnTeamID: \(bad.map(\.teamID))")
  }

  func test_f1_kickSauber_isInCatalog() {
    let ks = TeamCatalog.all.filter { $0.sport == .f1 && $0.name == "Kick Sauber" }
    XCTAssertEqual(ks.count, 2, "Kick Sauber should have 2 driver entries (Hülkenberg + Bortoleto)")
  }

  func test_f1_raceLabel_includesDriver() {
    // raceLabel must include the driver name for racing sports — drives widget TeamHeader.
    let team = TeamCatalog.all.first { $0.sport == .f1 && $0.driverNames.contains("Hamilton") }
    XCTAssertNotNil(team)
    XCTAssertTrue(team?.raceLabel.contains("Hamilton") == true ||
                  team?.raceLabel.contains("Lewis Hamilton") == true,
      "raceLabel must include the driver name")
    XCTAssertTrue(team?.raceLabel.contains("Ferrari") == true,
      "raceLabel must include the constructor name")
  }

  // MARK: MotoGP catalog coverage

  func test_motoGP_ducati_displayName_isJustDucati() {
    // "Ducati Lenovo" was the old name — verify it's been corrected.
    let ducati = TeamCatalog.all.filter {
      $0.sport == .motoGP && $0.espnTeamID == "motogp_ducati_lenovo"
    }
    XCTAssertFalse(ducati.isEmpty)
    for entry in ducati {
      XCTAssertFalse(entry.displayName.localizedCaseInsensitiveContains("Lenovo"),
        "Ducati display name should not include 'Lenovo' — it was removed in Build 16")
      XCTAssertEqual(entry.displayName, "Ducati")
    }
  }

  func test_motoGP_allEntries_haveDriverDisplayName() {
    let missing = TeamCatalog.all.filter {
      $0.sport == .motoGP && ($0.driverDisplayName == nil || $0.driverDisplayName?.isEmpty == true)
    }
    XCTAssertTrue(missing.isEmpty, "MotoGP entries missing driverDisplayName: \(missing.map(\.teamID))")
  }
}

// MARK: - HomeTeamTeamSummary formatting
// shortenPlace and inlineDisplay bugs would be caught here.

final class HomeTeamTeamSummaryTests: XCTestCase {

  private func summary(record: String = "38-30-14", place: String, last10: String = "6-3-1", streak: String = "W3") -> HomeTeamTeamSummary {
    HomeTeamTeamSummary(compositeID: "nhl:22", record: record, place: place,
                        last10: last10, streak: streak, style: .standard)
  }

  func test_shortenPlace_nationalFootballConference() {
    XCTAssertTrue(summary(place: "3rd in National Football Conference").inlineDisplay.contains("NFC"))
    XCTAssertFalse(summary(place: "3rd in National Football Conference").inlineDisplay.contains("National Football Conference"))
  }

  func test_shortenPlace_americanFootballConference() {
    XCTAssertTrue(summary(place: "1st in American Football Conference").inlineDisplay.contains("AFC"))
  }

  func test_shortenPlace_metropolitanDivision() {
    let display = summary(place: "2nd in Metropolitan Division").inlineDisplay
    XCTAssertTrue(display.contains("Metro Div."))
    XCTAssertFalse(display.contains("Metropolitan Division"))
  }

  func test_shortenPlace_nationalLeague() {
    XCTAssertTrue(summary(place: "5th in National League").inlineDisplay.contains("NL"))
  }

  func test_shortenPlace_unknownDivision_passesThrough() {
    let place = "1st in Imaginary Division"
    XCTAssertTrue(summary(place: place).inlineDisplay.contains(place))
  }

  func test_inlineDisplay_standard_format() {
    let s = summary(record: "38-30-14", place: "10th in Eastern Conference", last10: "6-3-1", streak: "W3")
    let d = s.inlineDisplay
    XCTAssertTrue(d.contains("38-30-14"))
    XCTAssertTrue(d.contains("L10 6-3-1"))
    XCTAssertTrue(d.contains("W3"))
    XCTAssertTrue(d.contains("East. Conf."))
  }

  func test_inlineDisplay_racing_format() {
    let s = HomeTeamTeamSummary(compositeID: "f1:hamilton", record: "131", place: "2",
                                last10: "2", streak: "5", style: .racingDriver)
    let d = s.inlineDisplay
    XCTAssertTrue(d.contains("Pts 131"))
    XCTAssertTrue(d.contains("Place 2"))
    XCTAssertTrue(d.contains("Wins 2"))
    XCTAssertTrue(d.contains("Podiums 5"))
  }
}
