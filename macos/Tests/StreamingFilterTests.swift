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
    // TNT sports content streams on Max
    XCTAssertEqual(StreamingServiceMatcher.canonicalKey(for: "TNT"), "max")
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

  func test_containerURL_isNonNil() {
    XCTAssertNotNil(AppGroupStore.containerURL,
      "App Group container must be accessible. Check entitlements and portal registration.")
  }

  func test_roundTrip_appSettings() throws {
    let original = AppSettings.default
    try AppGroupStore.write(original, to: "test_settings.json")
    let loaded = try AppGroupStore.read(AppSettings.self, from: "test_settings.json")
    XCTAssertEqual(original, loaded)
  }
}
