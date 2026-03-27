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

  func test_status_nil_futureDate_mapsScheduled() throws {
    // Future date with nil status → still scheduled
    let json = motogpJSON(dateStart: "2026-03-29", status: nil)
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertEqual(games[0].status, .scheduled)
  }

  func test_status_nil_pastDate_mapsFinal() throws {
    // isFinished=true endpoint can return events with null status field.
    // Any event with a past date should be treated as final.
    let json = motogpJSON(dateStart: "2020-06-01", status: nil)
    let games = try MotoGPCalendarParser.parse(json)
    XCTAssertEqual(games[0].status, .final,
      "Past-date event with nil status must be .final so it appears in the PREVIOUS section")
  }

  func test_status_unknown_pastDate_mapsFinal() throws {
    // PulseLive uses "CLOSED"/"COMPLETED"/"ENDED" in some API versions; must all map to .final
    for s in ["CLOSED", "COMPLETED", "ENDED", "RANDOM_UNKNOWN"] {
      let json = motogpJSON(dateStart: "2020-06-01", status: s)
      let games = try MotoGPCalendarParser.parse(json)
      XCTAssertEqual(games[0].status, .final,
        "Past-date event with status '\(s)' must be .final")
    }
  }

  func test_status_closed_futureDate_mapsScheduled() throws {
    // Pathological: future date with unrecognized status → treat as scheduled
    let json = motogpJSON(dateStart: "2027-01-01", status: "UNKNOWN")
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

  // MARK: Name storage
  // ESPNRacingParser stores the raw event name verbatim.
  // compactRaceName() is called at display time (widget + app) to strip sponsors.

  func test_homeTeamName_storedVerbatim() throws {
    // Raw name preserved — sponsor stripping happens at display time via compactRaceName()
    let json = espnJSON(name: "Aramco Japanese Grand Prix",
                        competitions: [comp(typeId: 3, date: "2026-03-29T05:00Z")])
    let games = try ESPNRacingParser.parse(json, sport: .f1)
    XCTAssertEqual(games[0].homeTeamName, "Aramco Japanese Grand Prix")
    XCTAssertEqual(GameFormatters.compactRaceName(from: games[0].homeTeamName), "Japanese GP",
      "compactRaceName must strip sponsor prefix from verbatim ESPN name")
  }

  func test_sponsorPlusLocation_compactsToLocationGP() throws {
    // Crypto.com Miami Grand Prix → Miami GP, Lenovo Canadian Grand Prix → Canadian GP
    for (raw, expected) in [
      ("Crypto.com Miami Grand Prix", "Miami GP"),
      ("Lenovo Canadian Grand Prix", "Canadian GP"),
      ("Japanese Grand Prix", "Japanese GP"),
    ] {
      XCTAssertEqual(GameFormatters.compactRaceName(from: raw), expected,
        "Failed for input '\(raw)'")
    }
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

  // MotoGPCalendarParser pre-converts "Grand Prix" → "GP" before
  // compactRaceName receives the string. F1 names are stored verbatim and
  // handled by the "Grand Prix" extractor above.
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

  // MotoGP logoFileURL returns nil for a non-existent team ID.
  func test_logoFileURL_motoGP_nonexistentID_isNil() {
    XCTAssertNil(AppGroupStore.logoFileURL(sport: .motoGP, espnTeamID: "motogp_does_not_exist_xyzzy"),
      "logoFileURL must return nil for a MotoGP teamID with no file on disk")
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

  // ESPN schedule + standings APIs both use these IDs — verified via live API curl.
  func test_nhl_washingtonCapitals_espnTeamID() {
    let team = TeamCatalog.all.first { $0.sport == .nhl && $0.name == "Capitals" }
    XCTAssertNotNil(team)
    XCTAssertEqual(team?.espnTeamID, "23",
      "Washington Capitals ESPN ID is 23 (schedule + standings API confirmed).")
  }

  func test_nhl_seattleKraken_espnTeamID() {
    let team = TeamCatalog.all.first { $0.sport == .nhl && $0.name == "Kraken" }
    XCTAssertNotNil(team)
    XCTAssertEqual(team?.espnTeamID, "124292",
      "Seattle Kraken ESPN ID is 124292 (expansion team, not a low integer).")
  }

  func test_nhl_vancouverCanucks_espnTeamID() {
    let team = TeamCatalog.all.first { $0.sport == .nhl && $0.name == "Canucks" }
    XCTAssertEqual(team?.espnTeamID, "22")
  }

  func test_nhl_sanJoseSharks_espnTeamID() {
    let team = TeamCatalog.all.first { $0.sport == .nhl && $0.name == "Sharks" }
    XCTAssertEqual(team?.espnTeamID, "18")
  }

  func test_nhl_winnipegJets_espnTeamID() {
    let team = TeamCatalog.all.first { $0.sport == .nhl && $0.name == "Jets" }
    XCTAssertEqual(team?.espnTeamID, "28")
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

  func test_inlineDisplay_hides_l10_when_missing() {
    // NFL/off-season: ESPN returns "-" for last10 — don't show "L10 -"
    let s = summary(place: "14th in NFC", last10: "-", streak: "W1")
    XCTAssertFalse(s.inlineDisplay.contains("L10"))
    XCTAssertTrue(s.inlineDisplay.contains("W1"))
  }

  func test_inlineDisplay_hides_streak_when_missing() {
    let s = summary(place: "10th in East. Conf.", last10: "6-3-1", streak: "-")
    XCTAssertTrue(s.inlineDisplay.contains("L10 6-3-1"))
    XCTAssertFalse(s.inlineDisplay.hasSuffix("-"))
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

// MARK: - Widget game filter (1A)

final class WidgetGameFilterTests: XCTestCase {

  private let now = Date(timeIntervalSince1970: 1_700_000_000)   // 2023-11-14 ~10:13 UTC
  private let hour: TimeInterval = 3600

  // MARK: Live filtering

  func test_live_includesLiveGames() {
    let games = [makeGame(id: "1", status: .live)]
    let result = filter(games, sport: .nhl)
    XCTAssertEqual(result.live.count, 1)
  }

  func test_live_excludesFinalGames() {
    let games = [makeGame(id: "1", status: .final, at: now - hour)]
    let result = filter(games, sport: .nhl)
    XCTAssertTrue(result.live.isEmpty)
  }

  func test_live_excludesScheduledGames() {
    let games = [makeGame(id: "1", status: .scheduled, at: now + hour)]
    let result = filter(games, sport: .nhl)
    XCTAssertTrue(result.live.isEmpty)
  }

  // MARK: Previous filtering

  func test_previous_includesFinalBeforeNow() {
    let games = [makeGame(id: "1", status: .final, at: now - hour)]
    let result = filter(games, sport: .nhl)
    XCTAssertEqual(result.previous.count, 1)
  }

  func test_previous_excludesFinalAfterNow() {
    let games = [makeGame(id: "1", status: .final, at: now + hour)]
    let result = filter(games, sport: .nhl)
    XCTAssertTrue(result.previous.isEmpty)
  }

  func test_previous_excludesLiveGames() {
    let games = [makeGame(id: "1", status: .live, at: now - hour)]
    let result = filter(games, sport: .nhl)
    XCTAssertTrue(result.previous.isEmpty)
  }

  func test_previous_sortedNewestFirst() {
    let games = (1...5).map { i in
      makeGame(id: "\(i)", status: .final, at: now - Double(i) * hour)
    }
    let result = filter(games, sport: .nhl)
    XCTAssertEqual(result.previous.map(\.id), ["1", "2", "3"],
      "Should be sorted newest-first")
  }

  func test_previous_limitedTo3() {
    let games = (1...10).map { i in
      makeGame(id: "\(i)", status: .final, at: now - Double(i) * hour)
    }
    let result = filter(games, sport: .nhl)
    XCTAssertEqual(result.previous.count, 3)
  }

  // MARK: Upcoming filtering

  func test_upcoming_includesScheduledAfterNow() {
    let games = [makeGame(id: "1", status: .scheduled, at: now + hour)]
    let result = filter(games, sport: .nhl)
    XCTAssertEqual(result.upcoming.count, 1)
  }

  func test_upcoming_excludesScheduledBeforeNow() {
    let games = [makeGame(id: "1", status: .scheduled, at: now - hour)]
    let result = filter(games, sport: .nhl)
    XCTAssertTrue(result.upcoming.isEmpty)
  }

  func test_upcoming_excludesFinalGames() {
    let games = [makeGame(id: "1", status: .final, at: now + hour)]
    let result = filter(games, sport: .nhl)
    XCTAssertTrue(result.upcoming.isEmpty)
  }

  func test_upcoming_sortedEarliestFirst() {
    let games = (1...5).map { i in
      makeGame(id: "\(i)", status: .scheduled, at: now + Double(6 - i) * hour)
    }
    let result = filter(games, sport: .nhl)
    // Earliest (smallest offset) should be first
    XCTAssertEqual(result.upcoming.map(\.id), ["5", "4", "3"])
  }

  func test_upcoming_limitedTo3() {
    let games = (1...10).map { i in
      makeGame(id: "\(i)", status: .scheduled, at: now + Double(i) * hour)
    }
    let result = filter(games, sport: .nhl)
    XCTAssertEqual(result.upcoming.count, 3)
  }

  // MARK: Team matching

  func test_racing_matchesBySport() {
    let games = [makeGame(id: "1", sport: .f1, status: .live, homeTeamID: "", awayTeamID: "")]
    let team = makeTeamDef(sport: .f1, espnTeamID: "999")
    let result = WidgetGameFilter.filter(games: games, for: team, streamingKeys: [], now: now)
    XCTAssertEqual(result.live.count, 1)
  }

  func test_racing_doesNotMatchDifferentSport() {
    let games = [makeGame(id: "1", sport: .motoGP, status: .live, homeTeamID: "", awayTeamID: "")]
    let team = makeTeamDef(sport: .f1, espnTeamID: "999")
    let result = WidgetGameFilter.filter(games: games, for: team, streamingKeys: [], now: now)
    XCTAssertEqual(result.live.count, 0)
  }

  func test_teamSport_matchesByHomeTeamID() {
    let games = [makeGame(id: "1", status: .live, homeTeamID: "23", awayTeamID: "99")]
    let team = makeTeamDef(sport: .nhl, espnTeamID: "23")
    let result = WidgetGameFilter.filter(games: games, for: team, streamingKeys: [], now: now)
    XCTAssertEqual(result.live.count, 1)
  }

  func test_teamSport_matchesByAwayTeamID() {
    let games = [makeGame(id: "1", status: .live, homeTeamID: "99", awayTeamID: "23")]
    let team = makeTeamDef(sport: .nhl, espnTeamID: "23")
    let result = WidgetGameFilter.filter(games: games, for: team, streamingKeys: [], now: now)
    XCTAssertEqual(result.live.count, 1)
  }

  func test_teamSport_excludesNonMatchingTeamID() {
    let games = [makeGame(id: "1", status: .live, homeTeamID: "55", awayTeamID: "66")]
    let team = makeTeamDef(sport: .nhl, espnTeamID: "23")
    let result = WidgetGameFilter.filter(games: games, for: team, streamingKeys: [], now: now)
    XCTAssertEqual(result.live.count, 0)
  }

  // MARK: Streaming filter

  func test_streamingFilter_passesAll_whenNoSelection() {
    let games = [makeGame(id: "1", status: .scheduled, at: now + hour, broadcasts: ["Peacock"])]
    let result = filter(games, sport: .nhl, streamingKeys: [])
    XCTAssertEqual(result.upcoming.count, 1)
  }

  func test_streamingFilter_passesMatching() {
    let games = [makeGame(id: "1", status: .scheduled, at: now + hour, broadcasts: ["ESPN+"])]
    let result = filter(games, sport: .nhl, streamingKeys: ["espnplus"])
    XCTAssertEqual(result.upcoming.count, 1)
  }

  func test_streamingFilter_hidesNonMatching() {
    let games = [makeGame(id: "1", status: .scheduled, at: now + hour, broadcasts: ["Peacock"])]
    let result = filter(games, sport: .nhl, streamingKeys: ["espnplus"])
    XCTAssertTrue(result.upcoming.isEmpty)
  }

  // MARK: Off-season

  func test_isOffSeason_true_whenNoUpcomingAndNotRacing() {
    let games = [makeGame(id: "1", status: .final, at: now - hour)]
    let result = filter(games, sport: .nhl)
    XCTAssertTrue(result.isOffSeason)
  }

  func test_isOffSeason_false_forRacingSports() {
    let games = [makeGame(id: "1", sport: .f1, status: .final, at: now - hour,
                          homeTeamID: "", awayTeamID: "")]
    let team = makeTeamDef(sport: .f1, espnTeamID: "1")
    let result = WidgetGameFilter.filter(games: games, for: team, streamingKeys: [], now: now)
    XCTAssertFalse(result.isOffSeason)
  }

  // MARK: Helpers

  private func filter(
    _ games: [HomeTeamGame],
    sport: SupportedSport,
    streamingKeys: Set<String> = []
  ) -> WidgetGameFilter.Result {
    let team = makeTeamDef(sport: sport, espnTeamID: "1")
    return WidgetGameFilter.filter(games: games, for: team, streamingKeys: streamingKeys, now: now)
  }

  private func makeTeamDef(sport: SupportedSport, espnTeamID: String) -> TeamDefinition {
    TeamDefinition(
      teamID: "test_\(espnTeamID)", sport: sport,
      city: "", name: "Test", displayName: "Test", abbreviation: "TST",
      driverNames: [], espnTeamID: espnTeamID, driverDisplayName: nil
    )
  }

  private func makeGame(
    id: String,
    sport: SupportedSport = .nhl,
    status: GameStatus = .scheduled,
    at scheduledAt: Date? = nil,
    homeTeamID: String = "1",
    awayTeamID: String = "2",
    broadcasts: [String] = []
  ) -> HomeTeamGame {
    HomeTeamGame(
      id: id, sport: sport,
      homeTeamID: homeTeamID, awayTeamID: awayTeamID,
      homeTeamName: "Home", awayTeamName: "Away",
      homeTeamAbbrev: "HOM", awayTeamAbbrev: "AWY",
      homeScore: nil, awayScore: nil,
      homeRecord: nil, awayRecord: nil,
      scheduledAt: scheduledAt ?? now, status: status,
      statusDetail: nil, venueName: nil,
      broadcastNetworks: broadcasts,
      isPlayoff: false, seriesInfo: nil, racingResults: nil
    )
  }
}

// MARK: - Race points (1E)

final class RacePointsTests: XCTestCase {

  func test_motogp_p1_is25() {
    XCTAssertEqual(GameFormatters.racePoints(for: 1, sport: .motoGP), 25)
  }

  func test_f1_p1_is25() {
    XCTAssertEqual(GameFormatters.racePoints(for: 1, sport: .f1), 25)
  }

  func test_f1_p2_is18() {
    XCTAssertEqual(GameFormatters.racePoints(for: 2, sport: .f1), 18)
  }

  func test_f1_p10_is1() {
    XCTAssertEqual(GameFormatters.racePoints(for: 10, sport: .f1), 1)
  }

  func test_f1_p11_isNil() {
    XCTAssertNil(GameFormatters.racePoints(for: 11, sport: .f1))
  }

  func test_motogp_dnf_isNil() {
    XCTAssertNil(GameFormatters.racePoints(for: 0, sport: .motoGP))
  }

  func test_nonRacing_isNil() {
    XCTAssertNil(GameFormatters.racePoints(for: 1, sport: .nhl))
  }
}

// MARK: - Race flag (1F)

final class RaceFlagTests: XCTestCase {

  func test_japanese() {
    XCTAssertEqual(GameFormatters.raceFlag(for: "Japanese Grand Prix"), "🇯🇵")
  }

  func test_americas() {
    XCTAssertEqual(GameFormatters.raceFlag(for: "Americas GP"), "🇺🇸")
  }

  func test_thailand() {
    XCTAssertEqual(GameFormatters.raceFlag(for: "Thailand GP"), "🇹🇭")
  }

  func test_unknown_returnsNil() {
    XCTAssertNil(GameFormatters.raceFlag(for: "Unknown Location GP"))
  }

  func test_brazil() {
    XCTAssertEqual(GameFormatters.raceFlag(for: "Brazil GP"), "🇧🇷")
  }

  func test_qatar() {
    XCTAssertEqual(GameFormatters.raceFlag(for: "Qatar GP"), "🇶🇦")
  }
}

// MARK: - ScheduleSnapshot merge — remaining tests (1G)

extension ScheduleSnapshotTests {

  func test_nonDestructiveMerge_bothHaveGames_usesNew() {
    let cached = ScheduleSnapshot(games: [makeGame(id: "old")], fetchedAt: Date(timeIntervalSinceNow: -60))
    let fresh  = ScheduleSnapshot(games: [makeGame(id: "new")], fetchedAt: Date())
    let merged = cached.mergingNondestructively(with: fresh)
    XCTAssertEqual(merged.games.map(\.id), ["new"])
  }

  func test_nonDestructiveMerge_bothEmpty_staysEmpty() {
    let cached = ScheduleSnapshot(games: [], fetchedAt: Date(timeIntervalSinceNow: -60))
    let fresh  = ScheduleSnapshot(games: [], fetchedAt: Date())
    let merged = cached.mergingNondestructively(with: fresh)
    XCTAssertTrue(merged.games.isEmpty)
  }

  func test_nonDestructiveMerge_newSummaries_replaceExisting() {
    let oldSummary = HomeTeamTeamSummary(compositeID: "nhl:1", record: "10-5", place: "1st",
                                         last10: "7-3", streak: "W2", style: .standard)
    let newSummary = HomeTeamTeamSummary(compositeID: "nhl:1", record: "11-5", place: "1st",
                                         last10: "8-2", streak: "W3", style: .standard)
    let cached = ScheduleSnapshot(games: [makeGame(id: "1")], fetchedAt: Date(timeIntervalSinceNow: -60),
                                  teamSummaries: [oldSummary])
    let fresh  = ScheduleSnapshot(games: [makeGame(id: "1")], fetchedAt: Date(),
                                  teamSummaries: [newSummary])
    let merged = cached.mergingNondestructively(with: fresh)
    XCTAssertEqual(merged.teamSummaries.first?.record, "11-5")
  }

  func test_nonDestructiveMerge_emptySummaries_keepsExisting() {
    let summary = HomeTeamTeamSummary(compositeID: "nhl:1", record: "10-5", place: "1st",
                                      last10: "7-3", streak: "W2", style: .standard)
    let cached = ScheduleSnapshot(games: [makeGame(id: "1")], fetchedAt: Date(timeIntervalSinceNow: -60),
                                  teamSummaries: [summary])
    let fresh  = ScheduleSnapshot(games: [makeGame(id: "1")], fetchedAt: Date(),
                                  teamSummaries: [])
    let merged = cached.mergingNondestructively(with: fresh)
    XCTAssertEqual(merged.teamSummaries.first?.record, "10-5",
      "Empty incoming summaries should not wipe existing")
  }
}

// MARK: - App settings persistence — remaining tests (1H)

extension AppGroupStoreTests {

  func test_roundTrip_withFavoritesAndStreaming() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)
    var settings = AppSettings.default
    settings.favoriteTeamCompositeIDs = ["nhl:23", "f1:hamilton"]
    settings.selectedStreamingServices = ["espnplus", "max"]
    settings.zipCode = "20001"
    try AppGroupStore.write(settings, to: "test_settings_full.json")
    let loaded = try AppGroupStore.read(AppSettings.self, from: "test_settings_full.json")
    XCTAssertEqual(loaded.favoriteTeamCompositeIDs, ["nhl:23", "f1:hamilton"])
    XCTAssertEqual(loaded.selectedStreamingServices, ["espnplus", "max"])
    XCTAssertEqual(loaded.zipCode, "20001")
  }

  func test_roundTrip_preservesNotificationSettings() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)
    var settings = AppSettings.default
    settings.notifications.gameStarting = false
    settings.notifications.scoreUpdates = true
    try AppGroupStore.write(settings, to: "test_settings_notif.json")
    let loaded = try AppGroupStore.read(AppSettings.self, from: "test_settings_notif.json")
    XCTAssertEqual(loaded.notifications.gameStarting, false)
    XCTAssertEqual(loaded.notifications.scoreUpdates, true)
    XCTAssertEqual(loaded.notifications.finalScore, true) // default
  }

  func test_decoding_defaultSettings_matchesStatic() throws {
    try XCTSkipIf(ProcessInfo.processInfo.environment["CI"] != nil)
    // Encode default, decode, confirm identical
    let original = AppSettings.default
    try AppGroupStore.write(original, to: "test_settings_default.json")
    let loaded = try AppGroupStore.read(AppSettings.self, from: "test_settings_default.json")
    XCTAssertEqual(original, loaded)
    XCTAssertTrue(loaded.favoriteTeamCompositeIDs.isEmpty)
    XCTAssertTrue(loaded.selectedStreamingServices.isEmpty)
  }
}

// MARK: - MotoGP circuit timezones (1I)

final class MotoGPCircuitTimezoneTests: XCTestCase {

  func test_circuitTimezone_COTA_isChicago() throws {
    let json = makeEventsJSON(legacyID: 101)
    let timezones = MotoGPCalendarParser.circuitTimezones(from: json)
    let tz = timezones.values.first
    XCTAssertEqual(tz?.identifier, "America/Chicago")
  }

  func test_circuitTimezone_Silverstone_isLondon() throws {
    let json = makeEventsJSON(legacyID: 42)
    let timezones = MotoGPCalendarParser.circuitTimezones(from: json)
    let tz = timezones.values.first
    XCTAssertEqual(tz?.identifier, "Europe/London")
  }

  func test_circuitTimezone_Motegi_isTokyo() throws {
    let json = makeEventsJSON(legacyID: 76)
    let timezones = MotoGPCalendarParser.circuitTimezones(from: json)
    let tz = timezones.values.first
    XCTAssertEqual(tz?.identifier, "Asia/Tokyo")
  }

  func test_circuitTimezone_unknownID_returnsEmpty() throws {
    let json = makeEventsJSON(legacyID: 999)
    let timezones = MotoGPCalendarParser.circuitTimezones(from: json)
    XCTAssertTrue(timezones.isEmpty)
  }

  func test_circuitTimezone_PhillipIsland_isMelbourne() throws {
    let json = makeEventsJSON(legacyID: 32)
    let timezones = MotoGPCalendarParser.circuitTimezones(from: json)
    let tz = timezones.values.first
    XCTAssertEqual(tz?.identifier, "Australia/Melbourne")
  }

  func test_circuitTimezone_Sepang_isKualaLumpur() throws {
    let json = makeEventsJSON(legacyID: 75)
    let timezones = MotoGPCalendarParser.circuitTimezones(from: json)
    let tz = timezones.values.first
    XCTAssertEqual(tz?.identifier, "Asia/Kuala_Lumpur")
  }

  private func makeEventsJSON(legacyID: Int) -> Data {
    """
    [{"id":"evt-tz","date_start":"2026-03-27","test":false,
      "circuit":{"legacy_id":\(legacyID),"name":"Test Circuit","place":"Test","nation":"TST"}}]
    """.data(using: .utf8)!
  }
}

// MARK: - HomeTeamGame patching (1O)

final class HomeTeamGamePatchingTests: XCTestCase {

  func test_patchingRacingResults_attachesResults() {
    let game = makeGame()
    let results = [RacingResultLine(position: 1, driverName: "Hamilton", teamName: "Mercedes",
                                    timeOrGap: nil, espnTeamID: nil)]
    let patched = game.patchingRacingResults(results)
    XCTAssertEqual(patched.racingResults?.count, 1)
    XCTAssertEqual(patched.racingResults?.first?.driverName, "Hamilton")
  }

  func test_patchingRacingResults_preservesOtherFields() {
    let game = makeGame()
    let patched = game.patchingRacingResults([])
    XCTAssertEqual(patched.id, game.id)
    XCTAssertEqual(patched.sport, game.sport)
    XCTAssertEqual(patched.homeTeamName, game.homeTeamName)
    XCTAssertEqual(patched.scheduledAt, game.scheduledAt)
    XCTAssertEqual(patched.status, game.status)
  }

  func test_patchingScheduledAt_updatesDate() {
    let game = makeGame()
    let newDate = Date(timeIntervalSince1970: 2_000_000_000)
    let patched = game.patchingScheduledAt(newDate)
    XCTAssertEqual(patched.scheduledAt, newDate)
  }

  func test_patchingScheduledAt_preservesOtherFields() {
    let game = makeGame()
    let patched = game.patchingScheduledAt(Date())
    XCTAssertEqual(patched.id, game.id)
    XCTAssertEqual(patched.sport, game.sport)
    XCTAssertEqual(patched.homeTeamName, game.homeTeamName)
    XCTAssertEqual(patched.status, game.status)
    XCTAssertEqual(patched.homeScore, game.homeScore)
  }

  func test_patching_updatesScoresAndDetail() {
    let game = makeGame()
    let patched = game.patching(homeScore: 3, awayScore: 1, statusDetail: "3rd Period")
    XCTAssertEqual(patched.homeScore, 3)
    XCTAssertEqual(patched.awayScore, 1)
    XCTAssertEqual(patched.statusDetail, "3rd Period")
    XCTAssertEqual(patched.id, game.id)
  }

  private func makeGame() -> HomeTeamGame {
    HomeTeamGame(
      id: "patch-test", sport: .nhl,
      homeTeamID: "1", awayTeamID: "2",
      homeTeamName: "Home", awayTeamName: "Away",
      homeTeamAbbrev: "HOM", awayTeamAbbrev: "AWY",
      homeScore: nil, awayScore: nil,
      homeRecord: "10-5", awayRecord: "8-7",
      scheduledAt: Date(timeIntervalSince1970: 1_700_000_000),
      status: .scheduled,
      statusDetail: nil, venueName: "Arena",
      broadcastNetworks: ["ESPN+"],
      isPlayoff: false, seriesInfo: nil, racingResults: nil
    )
  }
}
