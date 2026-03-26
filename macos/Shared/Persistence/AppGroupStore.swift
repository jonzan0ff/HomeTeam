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
