import XCTest
import Foundation

let testAppGroupID = "group.com.hometeam.shared"

final class AppGroupTests: XCTestCase {

  // MARK: - Test 1: Container URL resolves

  func testAppGroupContainerURLIsNonNil() {
    let url = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: testAppGroupID
    )
    XCTAssertNotNil(
      url,
      """
      containerURL returned nil for '\(testAppGroupID)'.
      This means either:
        1. The App Group is not registered in the Apple Developer portal, or
        2. The entitlement is missing/wrong in this test target's signing, or
        3. The DEVELOPMENT_TEAM in the build settings is not the account that owns the group.
      Fix: Certificates → Identifiers & Profiles → App Groups → confirm '\(testAppGroupID)' exists.
      """
    )
  }

  // MARK: - Test 2: Container is writable

  func testAppGroupContainerIsWritable() throws {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: testAppGroupID
    ) else {
      throw XCTSkip("Container URL is nil — testAppGroupContainerURLIsNonNil must pass first.")
    }

    let testFile = container.appendingPathComponent("smoketest_rw_\(UUID().uuidString).txt")
    let content = "HomeTeam AppGroup write test \(Date())"

    XCTAssertNoThrow(
      try content.write(to: testFile, atomically: true, encoding: .utf8),
      "Failed to write to App Group container at \(testFile.path)"
    )

    let read = try String(contentsOf: testFile, encoding: .utf8)
    XCTAssertEqual(read, content, "Read-back content does not match what was written.")

    try? FileManager.default.removeItem(at: testFile)
  }

  // MARK: - Test 3: JSON round-trip through the container

  func testAppGroupRoundTripJSON() throws {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: testAppGroupID
    ) else {
      throw XCTSkip("Container URL is nil — testAppGroupContainerURLIsNonNil must pass first.")
    }

    struct Payload: Codable, Equatable {
      let ping: Bool
      let value: Int
      let label: String
    }

    let original = Payload(ping: true, value: 42, label: "HomeTeam smoke test")
    let fileURL = container.appendingPathComponent("smoketest_json_\(UUID().uuidString).json")

    let encoded = try JSONEncoder().encode(original)
    try encoded.write(to: fileURL, options: .atomic)

    let data = try Data(contentsOf: fileURL)
    let decoded = try JSONDecoder().decode(Payload.self, from: data)

    XCTAssertEqual(decoded, original, "JSON decoded from App Group container does not match original.")

    try? FileManager.default.removeItem(at: fileURL)
  }

  // MARK: - Test 4: Cross-process proof — read file written by SmokeApp

  func testAppGroupDataWrittenBySmokeApp() throws {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: testAppGroupID
    ) else {
      throw XCTSkip("Container URL is nil — testAppGroupContainerURLIsNonNil must pass first.")
    }

    let fileURL = container.appendingPathComponent("smoke_test.json")

    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      throw XCTSkip(
        """
        smoke_test.json not found in App Group container.
        Run SmokeApp first so it writes the file, then re-run this test.
        Expected path: \(fileURL.path)
        """
      )
    }

    struct SmokePayload: Codable {
      let source: String
      let timestamp: String
    }

    let data = try Data(contentsOf: fileURL)
    let payload = try JSONDecoder().decode(SmokePayload.self, from: data)

    XCTAssertEqual(
      payload.source,
      "SmokeApp",
      """
      smoke_test.json exists but was not written by SmokeApp (source='\(payload.source)').
      The app and this test target are not sharing the same container.
      This is the App Group cross-process failure — check signing and provisioning.
      """
    )

    XCTAssertFalse(
      payload.timestamp.isEmpty,
      "Timestamp in smoke_test.json is empty — file may be corrupted."
    )

    print("✓ Cross-process proof: SmokeApp wrote at \(payload.timestamp), test runner read it from \(fileURL.path)")
  }
}
