import AppKit
import Foundation

enum HomeTeamMenuAbout {
  /// Standard macOS About panel; shows `AppTestVersion` as the main version line (not CFBundle*).
  static func presentStandardPanel() {
    NSApp.activate(ignoringOtherApps: true)
    let bundle = Bundle.main
    let marketing = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"

    let credits = """
    This test-handoff string is defined in code (AppTestVersion.swift), not in Xcode’s Version/Build fields.

    Xcode Info.plist (unchanged): \(marketing) (\(build))

    The same test string appears in Settings → About.
    """

    NSApp.orderFrontStandardAboutPanel(options: [
      .applicationName: "HomeTeam",
      .applicationVersion: AppTestVersion.displayString,
      .version: "\(marketing) (\(build))",
      .credits: NSAttributedString(
        string: credits,
        attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
      ),
    ])
  }
}
