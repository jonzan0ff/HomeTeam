import XCTest

enum HomeTeamUITestLaunch {
  static let appGroupIdentifier = "group.com.jonzanoff.hometeam"

  static func configure(
    _ app: XCUIApplication,
    resetOnLaunch: Bool,
    realAppGroup: Bool = false
  ) {
    var args = ["-hometeam_ui_testing"]
    if realAppGroup {
      args.append("-hometeam_real_app_group")
    }
    if resetOnLaunch {
      args.append("-hometeam_reset_on_launch")
    }
    app.launchArguments = args
  }

  static func waitUntilOnboardingDismissed(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
    let card = app.otherElements["onboarding.card"]
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if !card.exists {
        return true
      }
      RunLoop.current.run(until: Date().addingTimeInterval(0.25))
    }
    return !card.exists
  }

  /// Enables a streaming checkbox-style toggle by accessibility identifier.
  static func enableStreamingToggle(_ app: XCUIApplication, accessibilityId: String) -> Bool {
    let checkbox = app.checkBoxes[accessibilityId]
    if checkbox.waitForExistence(timeout: 6) {
      if (checkbox.value as? String) == "0" {
        checkbox.click()
      }
      return true
    }

    let toggle = app.switches[accessibilityId]
    if toggle.waitForExistence(timeout: 2) {
      if (toggle.value as? String) == "0" {
        toggle.click()
      }
      return true
    }

    return false
  }

  static func appGroupSettingsJSONURL() -> URL? {
    guard
      let container = FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupIdentifier
      )
    else {
      return nil
    }
    return container
      .appendingPathComponent("HomeTeam", isDirectory: true)
      .appendingPathComponent("app_settings.json", isDirectory: false)
  }

  static func favoriteCompositeIDsInAppGroupJSON() throws -> [String]? {
    guard let url = appGroupSettingsJSONURL(),
          FileManager.default.fileExists(atPath: url.path)
    else {
      return nil
    }
    let data = try Data(contentsOf: url)
    let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return obj?["favoriteTeamCompositeIDs"] as? [String]
  }
}
