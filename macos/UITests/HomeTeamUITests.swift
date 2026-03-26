import XCTest

final class HomeTeamUITests: XCTestCase {

  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launch()
  }

  // MARK: - Onboarding

  func test_onboarding_noTeams_showsPrompt() {
    // App with zero configured teams should show the onboarding prompt text
    let prompt = app.staticTexts["No teams selected"]
    XCTAssertTrue(prompt.waitForExistence(timeout: 3),
      "Empty state should show 'No teams selected' prompt")
  }

  // MARK: - App Group JSON

  func test_appGroup_snapshotFileWritten() throws {
    // Trigger a refresh and verify the snapshot JSON lands in the App Group container
    let containerURL = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: "group.com.hometeam.shared"
    )
    XCTAssertNotNil(containerURL, "App Group container must be accessible from UI test target")

    // Wait up to 10s for the snapshot file to appear after app launches
    let snapshotURL = containerURL!.appendingPathComponent("schedule_snapshot.json")
    let deadline = Date().addingTimeInterval(10)
    var found = false
    while Date() < deadline {
      if FileManager.default.fileExists(atPath: snapshotURL.path) {
        found = true
        break
      }
      Thread.sleep(forTimeInterval: 0.5)
    }
    XCTAssertTrue(found, "schedule_snapshot.json should be written to the App Group container on launch")
  }
}
