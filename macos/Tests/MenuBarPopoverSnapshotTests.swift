import XCTest
import SwiftUI
import AppKit
@testable import HomeTeam

// MARK: - Menu bar popover snapshot tests
//
// Renders MenuBarContentView (rev 2 popover) to PNG artifacts for five scenarios.
// These are NOT baseline-compared — the tests always write and always pass. The
// output lives in macos/Tests/__PopoverSnapshots__/ so a human (or an agent on
// the QA Mac) can inspect them after a run.
//
// Mirrors the NSHostingView → bitmapImageRepForCachingDisplay → PNG pipeline
// from WidgetSnapshotTests.swift.

@MainActor
final class MenuBarPopoverSnapshotTests: XCTestCase {

  private let popoverWidth: CGFloat = 320

  private var snapshotDir: URL {
    URL(fileURLWithPath: #file)
      .deletingLastPathComponent()        // macos/Tests/
      .appendingPathComponent("__PopoverSnapshots__")
  }

  override func setUp() async throws {
    try await super.setUp()
    resetSharedState()
  }

  override func tearDown() async throws {
    resetSharedState()
    try await super.tearDown()
  }

  // MARK: - Scenarios

  func test_no_live_games() {
    seedSnapshot(live: 0, upcoming: 3)
    capturePopover(named: "no_live_games")
  }

  func test_live_games() {
    seedSnapshot(live: 2, upcoming: 0)
    capturePopover(named: "live_games")
  }

  func test_update_available() {
    seedSnapshot(live: 0, upcoming: 3)
    AppState.shared.availableUpdate = makeRelease(version: "9.9.9")
    capturePopover(named: "update_available")
  }

  func test_installing_update() {
    seedSnapshot(live: 0, upcoming: 3)
    AppState.shared.availableUpdate = makeRelease(version: "9.9.9")
    AppState.shared.isInstallingUpdate = true
    AppState.shared.updateProgress = 0.42
    capturePopover(named: "installing_update")
  }

  func test_refreshing() async {
    seedSnapshot(live: 0, upcoming: 3)

    // `ScheduleRepository.isRefreshing` is `private(set)` — we can't write it
    // directly, so we kick off a real refresh on the shared instance (no
    // favorites configured → near-empty TaskGroup → minimal side effects) and
    // yield a few hops to let its synchronous prologue flip `isRefreshing` to
    // true before we capture. If the capture lands after the `defer` restores
    // `false`, the artifact will just show the idle state — acceptable
    // because these tests only produce artifacts for inspection.
    let task = Task { await ScheduleRepository.shared.refresh() }
    await Task.yield()
    await Task.yield()

    capturePopover(named: "refreshing")

    // Let the refresh finish so singleton state doesn't leak into other tests.
    _ = await task.value
  }

  // MARK: - Capture pipeline

  private func capturePopover(
    named name: String,
    file: StaticString = #file,
    line: UInt = #line
  ) {
    let view = MenuBarContentView()
      .environmentObject(AppSettingsStore.shared)
      .environmentObject(ScheduleRepository.shared)
      .environmentObject(AppState.shared)
      .frame(width: popoverWidth)
      .background(Color(white: 0.18))
      .environment(\.colorScheme, .dark)

    // SwiftUI's ImageRenderer (macOS 13+) is the correct path for offscreen
    // rendering — NSHostingView.cacheDisplay drops SwiftUI Text (CoreText/Metal,
    // not legacy AppKit CGContext).
    let renderer = ImageRenderer(content: view)
    renderer.proposedSize = ProposedViewSize(width: popoverWidth, height: nil)
    renderer.scale = 2.0

    guard let cgImage = renderer.cgImage else {
      XCTFail("ImageRenderer produced no CGImage for \(name)", file: file, line: line)
      return
    }
    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
      XCTFail("Failed to encode PNG for \(name)", file: file, line: line)
      return
    }

    do {
      try FileManager.default.createDirectory(
        at: snapshotDir, withIntermediateDirectories: true
      )
      let outURL = snapshotDir.appendingPathComponent("\(name).png")
      try pngData.write(to: outURL)
      print("📸 Wrote popover snapshot: \(outURL.path)")
    } catch {
      XCTFail("Failed to write \(name).png: \(error)", file: file, line: line)
    }
  }

  // MARK: - State helpers

  /// Overwrites the shared schedule snapshot with a synthetic game list.
  private func seedSnapshot(live: Int, upcoming: Int) {
    var games: [HomeTeamGame] = []
    for i in 0..<live {
      games.append(makeGame(
        id: "live-\(i)",
        status: .live,
        at: Date().addingTimeInterval(-600),
        homeAbbrev: "WSH",
        awayAbbrev: "NYR"
      ))
    }
    for i in 0..<upcoming {
      games.append(makeGame(
        id: "upc-\(i)",
        status: .scheduled,
        at: Date().addingTimeInterval(Double(i + 1) * 3600),
        homeAbbrev: "WSH",
        awayAbbrev: "BOS"
      ))
    }
    let snapshot = ScheduleSnapshot(
      games: games,
      fetchedAt: Date().addingTimeInterval(-120),
      teamSummaries: []
    )
    ScheduleSnapshotStore.shared.save(snapshot)
  }

  /// Clears every bit of singleton state the popover reads.
  private func resetSharedState() {
    AppState.shared.availableUpdate = nil
    AppState.shared.isInstallingUpdate = false
    AppState.shared.updateProgress = 0
    ScheduleSnapshotStore.shared.save(
      ScheduleSnapshot(games: [], fetchedAt: .distantPast, teamSummaries: [])
    )
  }

  private func makeGame(
    id: String,
    status: GameStatus,
    at scheduledAt: Date,
    homeAbbrev: String,
    awayAbbrev: String
  ) -> HomeTeamGame {
    HomeTeamGame(
      id: id,
      sport: .nhl,
      homeTeamID: "23",
      awayTeamID: "99",
      homeTeamName: homeAbbrev,
      awayTeamName: awayAbbrev,
      homeTeamAbbrev: homeAbbrev,
      awayTeamAbbrev: awayAbbrev,
      homeScore: status == .live ? 2 : nil,
      awayScore: status == .live ? 1 : nil,
      homeRecord: nil,
      awayRecord: nil,
      scheduledAt: scheduledAt,
      status: status,
      statusDetail: status == .live ? "2nd Period - 8:42" : nil,
      venueName: nil,
      broadcastNetworks: [],
      isPlayoff: false,
      seriesInfo: nil,
      racingResults: nil
    )
  }

  private func makeRelease(version: String) -> GitHubRelease {
    // GitHubRelease is Decodable-only; synthesize one via JSON so we don't
    // need to touch its memberwise init.
    let json = """
    {
      "tag_name": "v\(version)",
      "name": "v\(version)",
      "assets": [
        {
          "id": 1,
          "name": "HomeTeam-\(version).zip",
          "browser_download_url": "https://example.com/HomeTeam-\(version).zip"
        }
      ]
    }
    """
    let data = Data(json.utf8)
    return try! JSONDecoder().decode(GitHubRelease.self, from: data)
  }
}
