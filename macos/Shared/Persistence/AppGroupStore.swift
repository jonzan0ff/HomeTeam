import Foundation

// MARK: - Shared container access point

enum AppGroupStore {
  static let groupID = "group.com.hometeam.shared"

  static var containerURL: URL? {
    FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
  }

  // MARK: AppSettings (written by app, read by widget for streaming filter)
  static let settingsFilename  = "app_settings.json"
  // MARK: ScheduleSnapshot (written by app, read by widget)
  static let snapshotFilename  = "schedule_snapshot.json"
  // MARK: Logos (written by app during refresh, read by widget synchronously)
  static let logosDirname      = "logos"

  static var logosDirectoryURL: URL? {
    guard let container = containerURL else { return nil }
    let dir = container.appendingPathComponent(logosDirname)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  /// Returns the on-disk URL for a team logo, or nil if not yet downloaded / not supported.
  /// F1 and MotoGP: checks App Group container for .svg first, then .png.
  static func logoFileURL(sport: SupportedSport, espnTeamID: String) -> URL? {
    guard !espnTeamID.isEmpty, let dir = logosDirectoryURL else { return nil }
    if sport == .f1 {
      let svgURL = dir.appendingPathComponent("f1_\(espnTeamID).svg")
      if FileManager.default.fileExists(atPath: svgURL.path) { return svgURL }
      let pngURL = dir.appendingPathComponent("f1_\(espnTeamID).png")
      if FileManager.default.fileExists(atPath: pngURL.path) { return pngURL }
      return nil
    }
    if sport == .motoGP {
      let pngURL = dir.appendingPathComponent("motoGP_\(espnTeamID).png")
      if FileManager.default.fileExists(atPath: pngURL.path) { return pngURL }
      return nil
    }
    return dir.appendingPathComponent("\(sport.rawValue)_\(espnTeamID).png")
  }

  // MARK: Helpers

  static func url(for filename: String) -> URL? {
    containerURL?.appendingPathComponent(filename)
  }

  static func write<T: Encodable>(_ value: T, to filename: String) throws {
    guard let url = url(for: filename) else {
      throw AppGroupError.containerUnavailable
    }
    let data = try JSONEncoder().encode(value)
    try data.write(to: url, options: .atomic)
  }

  static func read<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
    guard let url = url(for: filename) else {
      throw AppGroupError.containerUnavailable
    }
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(type, from: data)
  }
}

enum AppGroupError: Error, LocalizedError {
  case containerUnavailable
  var errorDescription: String? {
    switch self {
    case .containerUnavailable:
      return "App Group container '\(AppGroupStore.groupID)' is not accessible. Check entitlements."
    }
  }
}
