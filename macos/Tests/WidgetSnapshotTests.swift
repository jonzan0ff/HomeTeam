import XCTest
import SwiftUI
import AppKit
@testable import HomeTeam

// MARK: - Layer 2: Widget snapshot tests
// Renders HomeTeamWidgetEntryView to PNG images for visual regression testing.
// Reference images are committed to qa/baselines/.
// On first run (or when `recordMode = true`), images are written. On subsequent runs,
// new renders are compared pixel-by-pixel against the reference.

final class WidgetSnapshotTests: XCTestCase {

  // Set to true to write new reference images (overwriting existing).
  private let recordMode = false

  // macOS large widget size
  private let widgetSize = CGSize(width: 329, height: 345)

  private var snapshotDir: URL {
    URL(fileURLWithPath: #file)
      .deletingLastPathComponent()        // macos/Tests/
      .deletingLastPathComponent()        // macos/
      .deletingLastPathComponent()        // project root
      .appendingPathComponent("qa")
      .appendingPathComponent("baselines")
  }

  // MARK: - NHL

  func test_nhl_typical() {
    let entry = makeNHLEntry(
      previous: [
        makeGame(id: "p1", status: .final, at: date(-3), homeAbbrev: "WSH", awayAbbrev: "UTA",
                 homeScore: 7, awayScore: 4, homeID: "23", awayID: "99"),
        makeGame(id: "p2", status: .final, at: date(-5), homeAbbrev: "WSH", awayAbbrev: "STL",
                 homeScore: 0, awayScore: 3, homeID: "23", awayID: "88"),
        makeGame(id: "p3", status: .final, at: date(-7), homeAbbrev: "COL", awayAbbrev: "WSH",
                 homeScore: 3, awayScore: 2, homeID: "77", awayID: "23"),
      ],
      upcoming: [
        makeGame(id: "u1", status: .scheduled, at: date(1), homeAbbrev: "WSH", awayAbbrev: "NJ",
                 homeID: "23", awayID: "66", broadcasts: ["HULU"]),
        makeGame(id: "u2", status: .scheduled, at: date(3), homeAbbrev: "PIT", awayAbbrev: "WSH",
                 homeID: "55", awayID: "23", broadcasts: ["MAX"]),
      ],
      summary: makeSummary(record: "36-28-9", place: "12th in East. Conf.", last10: "5-3-2", streak: "W1")
    )
    assertWidgetSnapshot(entry: entry, named: "nhl_typical")
  }

  func test_nhl_live_game() {
    let entry = makeNHLEntry(
      live: [
        makeGame(id: "l1", status: .live, at: date(0), homeAbbrev: "WSH", awayAbbrev: "NYR",
                 homeScore: 2, awayScore: 1, homeID: "23", awayID: "33",
                 statusDetail: "2nd Period - 8:42"),
      ],
      previous: [
        makeGame(id: "p1", status: .final, at: date(-2), homeAbbrev: "WSH", awayAbbrev: "PHI",
                 homeScore: 4, awayScore: 1, homeID: "23", awayID: "44"),
      ],
      upcoming: [
        makeGame(id: "u1", status: .scheduled, at: date(3), homeAbbrev: "BOS", awayAbbrev: "WSH",
                 homeID: "55", awayID: "23", broadcasts: ["ESPN+"]),
      ],
      summary: makeSummary(record: "36-28-9", place: "12th in East. Conf.", last10: "5-3-2", streak: "W1")
    )
    assertWidgetSnapshot(entry: entry, named: "nhl_live_game")
  }

  func test_nhl_offseason() {
    let entry = makeNHLEntry(
      previous: [
        makeGame(id: "p1", status: .final, at: date(-10), homeAbbrev: "WSH", awayAbbrev: "TBL",
                 homeScore: 3, awayScore: 5, homeID: "23", awayID: "44"),
      ],
      upcoming: [],
      isOffSeason: true,
      summary: makeSummary(record: "36-28-9", place: "12th in East. Conf.", last10: "-", streak: "-")
    )
    assertWidgetSnapshot(entry: entry, named: "nhl_offseason")
  }

  // MARK: - F1

  func test_f1_typical() {
    let team = makeTeamDef(sport: .f1, name: "Haas", displayName: "Haas",
                           abbrev: "HAS", driverDisplay: "Oliver Bearman")
    let entry = HomeTeamEntry(
      date: now,
      teamDefinition: team,
      teamSummary: makeRacingSummary(compositeID: team.compositeID, place: "5", pts: "17", wins: "0", podiums: "0"),
      isOffSeason: false,
      liveGames: [],
      previousGames: [
        makeRaceGame(id: "rp1", at: date(-7), raceName: "Chinese GP", results: [
          result(pos: 1, name: "K. Antonelli"), result(pos: 2, name: "G. Russell"),
          result(pos: 3, name: "L. Hamilton"), result(pos: 5, name: "O. Bearman"),
        ]),
        makeRaceGame(id: "rp2", at: date(-14), raceName: "Australian GP", results: [
          result(pos: 1, name: "G. Russell"), result(pos: 2, name: "K. Antonelli"),
          result(pos: 3, name: "C. Leclerc"), result(pos: 7, name: "O. Bearman"),
        ]),
      ],
      upcomingGames: [
        makeRaceGame(id: "ru1", at: date(2), raceName: "Japanese GP", status: .scheduled, broadcasts: ["Apple TV"]),
        makeRaceGame(id: "ru2", at: date(14), raceName: "Miami GP", status: .scheduled, broadcasts: ["Apple TV"]),
        makeRaceGame(id: "ru3", at: date(28), raceName: "Canadian GP", status: .scheduled, broadcasts: ["Apple TV"]),
      ],
      fetchedAt: now,
      streamingKeys: []
    )
    assertWidgetSnapshot(entry: entry, named: "f1_typical")
  }

  // MARK: - MotoGP

  func test_motogp_typical() {
    let team = makeTeamDef(sport: .motoGP, name: "Ducati", displayName: "Ducati",
                           abbrev: "DUC", driverDisplay: "Marc Marquez")
    let entry = HomeTeamEntry(
      date: now,
      teamDefinition: team,
      teamSummary: makeRacingSummary(compositeID: team.compositeID, place: "5", pts: "34", wins: "0", podiums: "0"),
      isOffSeason: false,
      liveGames: [],
      previousGames: [
        makeRaceGame(id: "mp1", at: date(-7), raceName: "Thailand GP", sport: .motoGP, results: [
          result(pos: 1, name: "M. Bezzecchi"), result(pos: 2, name: "P. Acosta"),
          result(pos: 3, name: "R. Fernandez"), result(pos: 0, name: "Marc Marquez"),
        ]),
        makeRaceGame(id: "mp2", at: date(-14), raceName: "Brazil GP", sport: .motoGP, results: [
          result(pos: 1, name: "M. Bezzecchi"), result(pos: 2, name: "J. Martin"),
          result(pos: 3, name: "F. Di Giannantonio"), result(pos: 4, name: "Marc Marquez"),
        ]),
      ],
      upcomingGames: [
        makeRaceGame(id: "mu1", at: date(2), raceName: "Americas GP", sport: .motoGP, status: .scheduled, broadcasts: ["FS1"]),
        makeRaceGame(id: "mu2", at: date(14), raceName: "Spain GP", sport: .motoGP, status: .scheduled, broadcasts: ["FS1"]),
        makeRaceGame(id: "mu3", at: date(28), raceName: "France GP", sport: .motoGP, status: .scheduled, broadcasts: ["FS1"]),
      ],
      fetchedAt: now,
      streamingKeys: []
    )
    assertWidgetSnapshot(entry: entry, named: "motogp_typical")
  }

  // MARK: - Empty states

  func test_unconfigured() {
    assertWidgetSnapshot(entry: .placeholder, named: "unconfigured")
  }

  func test_no_games() {
    let team = makeTeamDef(sport: .nhl, name: "Capitals", displayName: "Washington Capitals",
                           abbrev: "WSH", driverDisplay: nil)
    let entry = HomeTeamEntry(
      date: now,
      teamDefinition: team,
      teamSummary: nil,
      isOffSeason: false,
      liveGames: [],
      previousGames: [],
      upcomingGames: [],
      fetchedAt: now,
      streamingKeys: []
    )
    assertWidgetSnapshot(entry: entry, named: "no_games")
  }

  // MARK: - Snapshot infrastructure

  private func assertWidgetSnapshot(
    entry: HomeTeamEntry,
    named name: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let view = HomeTeamWidgetEntryView(entry: entry)
      .frame(width: widgetSize.width, height: widgetSize.height)
      .background(Color(nsColor: .windowBackgroundColor))
      .environment(\.colorScheme, .light)

    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = NSRect(origin: .zero, size: widgetSize)

    // Force layout
    hostingView.layoutSubtreeIfNeeded()

    guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
      XCTFail("Failed to create bitmap rep", file: file, line: line)
      return
    }
    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
      XCTFail("Failed to create PNG data", file: file, line: line)
      return
    }

    let refURL = snapshotDir.appendingPathComponent("\(name).png")

    if recordMode {
      // Write reference image
      try? FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
      do {
        try pngData.write(to: refURL)
        // In record mode, test passes but prints a reminder
        print("📸 Recorded snapshot: \(refURL.lastPathComponent)")
      } catch {
        XCTFail("Failed to write snapshot: \(error)", file: file, line: line)
      }
      return
    }

    // Compare mode
    guard let referenceData = try? Data(contentsOf: refURL) else {
      XCTFail("No reference image at \(refURL.path). Run with recordMode = true to generate.", file: file, line: line)
      return
    }

    if pngData != referenceData {
      // Write the failing image for inspection
      let failURL = snapshotDir.appendingPathComponent("\(name)_FAIL.png")
      try? pngData.write(to: failURL)
      XCTFail("Snapshot '\(name)' differs from reference. Failing image: \(failURL.path)", file: file, line: line)
    }
  }

  // MARK: - Helpers

  private let now = Date(timeIntervalSince1970: 1_711_500_000) // 2024-03-27 ~02:00 UTC
  private let day: TimeInterval = 86400

  private func date(_ daysFromNow: Int) -> Date {
    now.addingTimeInterval(Double(daysFromNow) * day)
  }

  private func makeNHLEntry(
    live: [HomeTeamGame] = [],
    previous: [HomeTeamGame],
    upcoming: [HomeTeamGame],
    isOffSeason: Bool = false,
    summary: HomeTeamTeamSummary? = nil
  ) -> HomeTeamEntry {
    let team = makeTeamDef(sport: .nhl, name: "Capitals", displayName: "Washington Capitals",
                           abbrev: "WSH", driverDisplay: nil)
    return HomeTeamEntry(
      date: now,
      teamDefinition: team,
      teamSummary: summary,
      isOffSeason: isOffSeason,
      liveGames: live,
      previousGames: previous,
      upcomingGames: upcoming,
      fetchedAt: now,
      streamingKeys: []
    )
  }

  private func makeTeamDef(
    sport: SupportedSport, name: String, displayName: String,
    abbrev: String, driverDisplay: String?
  ) -> TeamDefinition {
    TeamDefinition(
      teamID: "snap_\(name.lowercased())", sport: sport,
      city: sport.isRacing ? "" : "Washington", name: name, displayName: displayName,
      abbreviation: abbrev, driverNames: driverDisplay.map { [$0] } ?? [],
      espnTeamID: "23", driverDisplayName: driverDisplay
    )
  }

  private func makeGame(
    id: String, status: GameStatus, at scheduledAt: Date,
    homeAbbrev: String, awayAbbrev: String,
    homeScore: Int? = nil, awayScore: Int? = nil,
    homeID: String = "23", awayID: String = "99",
    statusDetail: String? = nil,
    broadcasts: [String] = []
  ) -> HomeTeamGame {
    HomeTeamGame(
      id: id, sport: .nhl,
      homeTeamID: homeID, awayTeamID: awayID,
      homeTeamName: homeAbbrev, awayTeamName: awayAbbrev,
      homeTeamAbbrev: homeAbbrev, awayTeamAbbrev: awayAbbrev,
      homeScore: homeScore, awayScore: awayScore,
      homeRecord: nil, awayRecord: nil,
      scheduledAt: scheduledAt, status: status,
      statusDetail: statusDetail, venueName: nil,
      broadcastNetworks: broadcasts,
      isPlayoff: false, seriesInfo: nil, racingResults: nil
    )
  }

  private func makeRaceGame(
    id: String, at scheduledAt: Date, raceName: String,
    sport: SupportedSport = .f1, status: GameStatus = .final,
    results: [RacingResultLine]? = nil, broadcasts: [String] = []
  ) -> HomeTeamGame {
    HomeTeamGame(
      id: id, sport: sport,
      homeTeamID: "", awayTeamID: "",
      homeTeamName: raceName, awayTeamName: "",
      homeTeamAbbrev: "", awayTeamAbbrev: "",
      homeScore: nil, awayScore: nil,
      homeRecord: nil, awayRecord: nil,
      scheduledAt: scheduledAt, status: status,
      statusDetail: nil, venueName: nil,
      broadcastNetworks: broadcasts,
      isPlayoff: false, seriesInfo: nil, racingResults: results
    )
  }

  private func result(pos: Int, name: String) -> RacingResultLine {
    RacingResultLine(position: pos, driverName: name, teamName: nil, timeOrGap: nil, espnTeamID: nil)
  }

  private func makeSummary(record: String, place: String, last10: String, streak: String) -> HomeTeamTeamSummary {
    HomeTeamTeamSummary(compositeID: "nhl:snap_capitals", record: record, place: place,
                        last10: last10, streak: streak, style: .standard)
  }

  private func makeRacingSummary(compositeID: String, place: String, pts: String, wins: String, podiums: String) -> HomeTeamTeamSummary {
    HomeTeamTeamSummary(compositeID: compositeID, record: pts, place: place,
                        last10: wins, streak: podiums, style: .racingDriver)
  }
}
