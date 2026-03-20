import XCTest

final class HomeTeamFrontendUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  @MainActor
  func testOnboardingAppearsAfterResetLaunch() throws {
    let app = launchApp(resetOnLaunch: true)

    guard waitForButton(
      app,
      id: "onboarding.openSettings",
      label: "Open Settings",
      timeout: 8
    ) != nil else {
      XCTFail("Expected onboarding actions to appear for first-run setup.")
      return
    }
    attachScreenshot(named: "01-onboarding-get-started")
  }

  @MainActor
  func testOnboardingQuickLinkRoutesToFavoriteTeamsSection() throws {
    let app = launchApp(resetOnLaunch: true)

    guard let favoriteTeamsButton = waitForButton(
      app,
      id: "onboarding.openFavoriteTeams",
      label: "Open Favorite Teams",
      timeout: 8
    ) else {
      XCTFail("Expected onboarding favorite teams quick-link button to exist.")
      return
    }

    favoriteTeamsButton.click()

    XCTAssertTrue(
      waitForHeading(
        app,
        id: "settings.heading.favoriteTeams",
        title: "Favorite Teams",
        timeout: 8
      ),
      "Expected settings to open and route to Favorite Teams section."
    )
    attachScreenshot(named: "02-settings-favorite-teams")
  }

  @MainActor
  func testOnboardingQuickLinkRoutesToStreamingServicesSection() throws {
    let app = launchApp(resetOnLaunch: true)

    guard let streamingButton = waitForButton(
      app,
      id: "onboarding.openStreamingServices",
      label: "Open Streaming Services",
      timeout: 8
    ) else {
      XCTFail("Expected onboarding streaming quick-link button to exist.")
      return
    }

    streamingButton.click()

    XCTAssertTrue(
      waitForHeading(
        app,
        id: "settings.heading.streamingServices",
        title: "Streaming Services",
        timeout: 8
      ),
      "Expected settings to open and route to Streaming Services section."
    )
    attachScreenshot(named: "03-settings-streaming-services")
  }

  @MainActor
  func testOnboardingQuickLinkRoutesToLocationSection() throws {
    let app = launchApp(resetOnLaunch: true)

    guard let locationButton = waitForButton(
      app,
      id: "onboarding.openLocation",
      label: "Open Location",
      timeout: 8
    ) else {
      XCTFail("Expected onboarding location quick-link button to exist.")
      return
    }

    locationButton.click()

    XCTAssertTrue(
      waitForHeading(
        app,
        id: "settings.heading.location",
        title: "Location",
        timeout: 8
      ),
      "Expected settings to open and route to Location section."
    )
    attachScreenshot(named: "04-settings-location")
  }

  @MainActor
  func testFavoriteTeamsPickerExpandedScreenshot() throws {
    let app = launchApp(resetOnLaunch: true)

    guard let favoriteTeamsButton = waitForButton(
      app,
      id: "onboarding.openFavoriteTeams",
      label: "Open Favorite Teams",
      timeout: 8
    ) else {
      XCTFail("Expected onboarding favorite teams quick-link button to exist.")
      return
    }

    favoriteTeamsButton.click()

    XCTAssertTrue(
      waitForHeading(
        app,
        id: "settings.heading.favoriteTeams",
        title: "Favorite Teams",
        timeout: 8
      ),
      "Expected settings to open and route to Favorite Teams section."
    )

    let sportPicker = app.popUpButtons["settings.favoriteTeams.sportPicker"]
    guard sportPicker.waitForExistence(timeout: 5) else {
      XCTFail("Sport picker not found.")
      return
    }
    sportPicker.click()
    let f1Item = app.menuItems["F1"]
    if f1Item.waitForExistence(timeout: 3) {
      f1Item.click()
    } else {
      // Dismiss menu before failing to avoid hanging UI test runner.
      sportPicker.click()
      XCTFail("F1 option not found in sport picker.")
      return
    }

    let teamPicker = app.popUpButtons["settings.favoriteTeams.teamPicker"]
    guard teamPicker.waitForExistence(timeout: 5) else {
      XCTFail("Team picker not found.")
      return
    }

    // Leave the team picker menu open to capture visible choices.
    teamPicker.click()
    _ = app.menuItems["A. Albon - Williams"].waitForExistence(timeout: 3)
    attachScreenshot(named: "05-settings-team-picker-expanded")
  }

  @discardableResult
  private func launchApp(resetOnLaunch: Bool) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-hometeam_ui_testing"]
    if resetOnLaunch {
      app.launchArguments.append("-hometeam_reset_on_launch")
    }

    app.launch()
    return app
  }

  private func attachScreenshot(named name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  private func waitForButton(
    _ app: XCUIApplication,
    id: String,
    label: String,
    timeout: TimeInterval
  ) -> XCUIElement? {
    let byID = app.buttons[id]
    if byID.waitForExistence(timeout: timeout) {
      return byID
    }

    let byLabel = app.buttons[label]
    if byLabel.waitForExistence(timeout: 2) {
      return byLabel
    }

    return nil
  }

  private func waitForHeading(
    _ app: XCUIApplication,
    id: String,
    title: String,
    timeout: TimeInterval
  ) -> Bool {
    let byID = app.staticTexts[id]
    if byID.waitForExistence(timeout: timeout) {
      return true
    }

    let byTitle = app.staticTexts[title]
    return byTitle.waitForExistence(timeout: 2)
  }
}
