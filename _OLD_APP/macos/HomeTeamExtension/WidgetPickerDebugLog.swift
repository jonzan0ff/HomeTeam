import Foundation

/// Writes one line per call into the App Group so we can tell if the widget extension ran (Console is unreliable for `Logger.info`).
enum WidgetPickerDebugLog {
  private static let appGroupIdentifier = "group.com.jonzanoff.hometeam"
  static func append(_ message: String) {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupIdentifier
    ) else {
      return
    }

    let directoryURL = container.appendingPathComponent("HomeTeam", isDirectory: true)
    let fileURL = directoryURL.appendingPathComponent("widget_picker_debug.log", isDirectory: false)

    try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let line = "\(formatter.string(from: Date())) \(message)\n"
    guard let data = line.data(using: .utf8) else {
      return
    }

    if !FileManager.default.fileExists(atPath: fileURL.path) {
      FileManager.default.createFile(atPath: fileURL.path, contents: data)
      return
    }

    guard let handle = try? FileHandle(forWritingTo: fileURL) else {
      return
    }
    defer { try? handle.close() }
    try? handle.seekToEnd()
    try? handle.write(contentsOf: data)
  }
}
