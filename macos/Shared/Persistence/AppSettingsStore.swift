import Foundation

struct AppSettingsStore {
  enum StoreError: Error, LocalizedError {
    case missingSharedContainer(appGroupIdentifier: String)

    var errorDescription: String? {
      switch self {
      case .missingSharedContainer(let appGroupIdentifier):
        return "Shared container unavailable for App Group '\(appGroupIdentifier)'."
      }
    }
  }

  private let directoryName: String
  private let fileName: String
  private let iCloudKey: String
  private let appGroupIdentifier: String
  private let customDirectoryURL: URL?
  private let cloudSyncEnabled: Bool
  private let sharedContainerOverrideEnvironmentKey: String
  private let processInfo: ProcessInfo

  init(
    directoryName: String = "HomeTeam",
    fileName: String = "app_settings.json",
    iCloudKey: String = "home_team_app_settings_v1",
    appGroupIdentifier: String = "group.com.jonzanoff.hometeam",
    customDirectoryURL: URL? = nil,
    cloudSyncEnabled: Bool = true,
    sharedContainerOverrideEnvironmentKey: String = "HOMETEAM_SHARED_CONTAINER_DIR",
    processInfo: ProcessInfo = .processInfo
  ) {
    self.directoryName = directoryName
    self.fileName = fileName
    self.iCloudKey = iCloudKey
    self.appGroupIdentifier = appGroupIdentifier
    self.customDirectoryURL = customDirectoryURL
    self.cloudSyncEnabled = cloudSyncEnabled
    self.sharedContainerOverrideEnvironmentKey = sharedContainerOverrideEnvironmentKey
    self.processInfo = processInfo
  }

  func load() -> AppSettings {
    if let local = loadLocal() {
      return local
    }

    if cloudSyncEnabled, let cloud = loadFromCloud() {
      try? saveLocal(cloud)
      return cloud
    }

    return .default
  }

  func loadFromCloud() -> AppSettings? {
    guard cloudSyncEnabled else {
      return nil
    }

    let store = NSUbiquitousKeyValueStore.default
    guard let data = store.data(forKey: iCloudKey) else {
      return nil
    }

    return try? JSONDecoder().decode(AppSettings.self, from: data)
  }

  func save(_ settings: AppSettings) {
    try? saveLocal(settings)
    if cloudSyncEnabled {
      saveToCloud(settings)
    }
  }

  func synchronizeCloudStore() {
    guard cloudSyncEnabled else {
      return
    }
    NSUbiquitousKeyValueStore.default.synchronize()
  }

  func recordRecentTeam(_ compositeID: String, maxCount: Int = 8) {
    var settings = load()
    var recents = settings.recentTeamCompositeIDs.filter { $0 != compositeID }
    recents.insert(compositeID, at: 0)
    settings.recentTeamCompositeIDs = Array(recents.prefix(maxCount))
    save(settings)
  }

  private func loadLocal() -> AppSettings? {
    for fileURL in storeFileURLs {
      if
        let data = try? Data(contentsOf: fileURL),
        let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
      {
        return decoded
      }
    }

    return nil
  }

  private func saveLocal(_ settings: AppSettings) throws {
    let directories = storeDirectoryCandidates
    guard !directories.isEmpty else {
      throw StoreError.missingSharedContainer(appGroupIdentifier: appGroupIdentifier)
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted]
    let data = try encoder.encode(settings)

    var lastError: Error?
    for directoryURL in directories {
      do {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: [.atomic])
        return
      } catch {
        lastError = error
      }
    }

    if let lastError {
      throw lastError
    }

    throw StoreError.missingSharedContainer(appGroupIdentifier: appGroupIdentifier)
  }

  private func saveToCloud(_ settings: AppSettings) {
    guard let data = try? JSONEncoder().encode(settings) else {
      return
    }

    let store = NSUbiquitousKeyValueStore.default
    store.set(data, forKey: iCloudKey)
    store.synchronize()
  }

  private var storeDirectoryCandidates: [URL] {
    var directories: [URL] = []

    if let customDirectoryURL {
      directories.append(customDirectoryURL.appendingPathComponent(directoryName, isDirectory: true))
      return uniqueURLs(directories)
    }

    if let overrideContainerURL = sharedContainerOverrideURL {
      directories.append(overrideContainerURL.appendingPathComponent(directoryName, isDirectory: true))
      return uniqueURLs(directories)
    }

    if allowsProcessLocalFallback {
      if let legacyDirectoryURL {
        directories.append(legacyDirectoryURL)
      }
      directories.append(FileManager.default.temporaryDirectory.appendingPathComponent(directoryName, isDirectory: true))
      return uniqueURLs(directories)
    }

    if let groupContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
      directories.append(groupContainer.appendingPathComponent(directoryName, isDirectory: true))
      return uniqueURLs(directories)
    }

    return uniqueURLs(directories)
  }

  private var storeFileURLs: [URL] {
    storeDirectoryCandidates.map { $0.appendingPathComponent(fileName) }
  }

  private var sharedContainerOverrideURL: URL? {
    guard customDirectoryURL == nil else {
      return nil
    }
    guard
      let rawValue = processInfo.environment[sharedContainerOverrideEnvironmentKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !rawValue.isEmpty
    else {
      return nil
    }
    return URL(fileURLWithPath: rawValue, isDirectory: true)
  }

  private var allowsProcessLocalFallback: Bool {
    processInfo.arguments.contains("-hometeam_ui_testing")
      || processInfo.environment["XCTestConfigurationFilePath"] != nil
  }

  private var legacyDirectoryURL: URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent(directoryName, isDirectory: true)
  }

  private func uniqueURLs(_ values: [URL]) -> [URL] {
    var seen = Set<String>()
    var ordered: [URL] = []
    for value in values {
      let path = value.standardizedFileURL.path
      if seen.insert(path).inserted {
        ordered.append(value)
      }
    }
    return ordered
  }
}
