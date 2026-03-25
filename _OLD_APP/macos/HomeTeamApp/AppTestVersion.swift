import Foundation

/// Human-visible version for UAT handoffs. Not CFBundleVersion.
/// Before each test request: increment by 0.001 and set timestamp to local handoff time.
enum AppTestVersion {
  static let displayString = "0.010 (Mar 21 22:15)"
}
