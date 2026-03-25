import XCTest

/// Exercises the **real** App Group container (same JSON the widget extension reads).
/// Default CI / `qa_ui_tests.sh` skips these via `XCTSkip` unless env is set.
///
/// - `HOMETEAM_UI_TEST_REAL_APP_GROUP=1` — non-destructive checks and flows that write favorites.
/// - `HOMETEAM_UI_TEST_DESTRUCTIVE_RESET=1` — additionally allows `-hometeam_reset_on_launch` (clears favorites + streaming in the shared container). Use a QA macOS user only.
final class HomeTeamSharedContainerUITests: XCTestCase {
  override func setUpWithError() throws {
    try super.setUpWithError()
    continueAfterFailure = false
    try XCTSkipIf(
      ProcessInfo.processInfo.environment["HOMETEAM_UI_TEST_REAL_APP_GROUP"] != "1",
      "Set HOMETEAM_UI_TEST_REAL_APP_GROUP=1 to run shared-container UI tests (see AGENTS.md)."
    )
  }

  @MainActor
  func testAppGroupContainerURLAvailable() throws {
    XCTAssertNotNil(
      FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: HomeTeamUITestLaunch.appGroupIdentifier
      ),
      "App Group container required for widget + app shared settings (signing / entitlements)."
    )
  }

  @MainActor
  func testAppGroupJSONFavoritesNonEmptyWhenFileExists() throws {
    let favorites = try HomeTeamUITestLaunch.favoriteCompositeIDsInAppGroupJSON()
    if favorites == nil {
      throw XCTSkip("No app_settings.json yet — launch the app once and add a favorite, or run the destructive UI flow.")
    }
    XCTAssertFalse(
      favorites!.isEmpty,
      "Empty favoriteTeamCompositeIDs reproduces an empty widget configuration picker; widget reads this file."
    )
  }

  @MainActor
  func testDestructiveResetThenOnboardingWritesFavoritesToAppGroup() throws {
    try XCTSkipIf(
      ProcessInfo.processInfo.environment["HOMETEAM_UI_TEST_DESTRUCTIVE_RESET"] != "1",
      "Set HOMETEAM_UI_TEST_DESTRUCTIVE_RESET=1 to allow reset (wipes shared favorites). QA macOS user only."
    )

    let app = XCUIApplication()
    HomeTeamUITestLaunch.configure(app, resetOnLaunch: true, realAppGroup: true)
    app.launch()

    let openFavoriteTeams = app.buttons["onboarding.openFavoriteTeams"]
    guard openFavoriteTeams.waitForExistence(timeout: 8) else {
      XCTFail("Expected onboarding favorite-teams control after reset.")
      return
    }
    openFavoriteTeams.click()

    XCTAssertTrue(
      app.staticTexts["settings.heading.favoriteTeams"].waitForExistence(timeout: 10),
      "Favorite Teams settings should open."
    )

    let addTeam = app.buttons["settings.favoriteTeams.addTeam"]
    XCTAssertTrue(addTeam.waitForExistence(timeout: 6), "Add Team button expected.")
    addTeam.click()

    XCTAssertTrue(
      app.buttons["onboarding.openStreamingServices"].waitForExistence(timeout: 8),
      "Return to main window onboarding for streaming step."
    )
    app.buttons["onboarding.openStreamingServices"].click()

    XCTAssertTrue(
      app.staticTexts["settings.heading.streamingServices"].waitForExistence(timeout: 10),
      "Streaming Services settings should open."
    )

    XCTAssertTrue(
      HomeTeamUITestLaunch.enableStreamingToggle(app, accessibilityId: "settings.streaming.toggle.espn-plus"),
      "Could not enable ESPN+ streaming toggle (checkbox/switch)."
    )

    XCTAssertTrue(
      app.buttons["onboarding.refreshStatus"].waitForExistence(timeout: 8),
      "Refresh Setup Status should be reachable on main window."
    )
    app.buttons["onboarding.refreshStatus"].click()

    XCTAssertTrue(
      HomeTeamUITestLaunch.waitUntilOnboardingDismissed(app, timeout: 20),
      "Onboarding should complete after favorite + streaming + refresh."
    )

    let favorites = try XCTUnwrap(try HomeTeamUITestLaunch.favoriteCompositeIDsInAppGroupJSON())
    XCTAssertFalse(
      favorites.isEmpty,
      "Shared app_settings.json should list favorites for the widget configuration query."
    )
  }
}
