import AppKit
import CryptoKit
import Foundation

struct SharedScheduleStore {
  enum StoreError: Error, LocalizedError {
    case missingSharedContainer(appGroupIdentifier: String)

    var errorDescription: String? {
      switch self {
      case .missingSharedContainer(let appGroupIdentifier):
        return "Shared container unavailable for App Group '\(appGroupIdentifier)'."
      }
    }
  }

  private let directoryName = "HomeTeam"
  private let appGroupIdentifier = "group.com.jonzanoff.hometeam"
  private let sharedContainerOverrideEnvironmentKey = "HOMETEAM_SHARED_CONTAINER_DIR"

  private var storeDirectoryCandidates: [URL] {
    var directories: [URL] = []

    if ProcessInfo.processInfo.arguments.contains("-hometeam_ui_testing") {
      directories.append(
        FileManager.default.temporaryDirectory
          .appendingPathComponent("HomeTeam-UITests", isDirectory: true)
          .appendingPathComponent(directoryName, isDirectory: true)
      )
      return uniqueURLs(directories)
    }

    if let overrideContainerRoot = sharedContainerOverrideRootURL {
      directories.append(overrideContainerRoot.appendingPathComponent(directoryName, isDirectory: true))
      return uniqueURLs(directories)
    }

    if allowsProcessLocalFallback {
      if let legacyStoreDirectoryURL {
        directories.append(legacyStoreDirectoryURL)
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

  private func storeURLs(for compositeTeamID: String) -> [URL] {
    storeDirectoryCandidates.map { $0.appendingPathComponent(fileName(for: compositeTeamID)) }
  }

  private var legacyStoreDirectoryURL: URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
      .appendingPathComponent(directoryName, isDirectory: true)
  }

  private func fileName(for compositeTeamID: String) -> String {
    let sanitized = compositeTeamID
      .lowercased()
      .replacingOccurrences(of: ":", with: "_")
      .replacingOccurrences(of: "/", with: "_")

    return "schedule_snapshot_\(sanitized).json"
  }

  func load() -> ScheduleSnapshot? {
    load(for: TeamCatalog.defaultTeamCompositeID)
  }

  func load(for compositeTeamID: String) -> ScheduleSnapshot? {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    for storeURL in storeURLs(for: compositeTeamID) {
      if
        let data = try? Data(contentsOf: storeURL),
        let decoded = try? decoder.decode(ScheduleSnapshot.self, from: data)
      {
        return decoded
      }
    }

    return nil
  }

  func save(_ snapshot: ScheduleSnapshot) throws {
    try save(snapshot, for: TeamCatalog.defaultTeamCompositeID)
  }

  func save(_ snapshot: ScheduleSnapshot, for compositeTeamID: String) throws {
    let targetURLs = storeURLs(for: compositeTeamID)
    guard !targetURLs.isEmpty else {
      throw StoreError.missingSharedContainer(appGroupIdentifier: appGroupIdentifier)
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(snapshot)

    var lastError: Error?
    for targetURL in targetURLs {
      do {
        try FileManager.default.createDirectory(
          at: targetURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try data.write(to: targetURL, options: [.atomic])
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

  private var sharedContainerOverrideRootURL: URL? {
    guard
      let rawValue = ProcessInfo.processInfo.environment[sharedContainerOverrideEnvironmentKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !rawValue.isEmpty
    else {
      return nil
    }
    return URL(fileURLWithPath: rawValue, isDirectory: true)
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

  private var allowsProcessLocalFallback: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  }
}

struct TeamLogoStore {
  private let rootDirectoryName = "HomeTeam"
  private let logoDirectoryName = "team_logos"
  private let appGroupIdentifier = "group.com.jonzanoff.hometeam"
  private let sharedContainerOverrideEnvironmentKey = "HOMETEAM_SHARED_CONTAINER_DIR"
  private static let nhlAbbreviations: Set<String> = [
    "ANA", "BOS", "BUF", "CGY", "CAR", "CHI", "COL", "CBJ",
    "DAL", "DET", "EDM", "FLA", "LAK", "MIN", "MTL", "NSH",
    "NJD", "NYI", "NYR", "OTT", "PHI", "PIT", "SEA", "SJS",
    "STL", "TBL", "TOR", "UTA", "VAN", "VGK", "WSH", "WPG",
    "ARI",
  ]

  private var logoDirectoryURLs: [URL] {
    let fileManager = FileManager.default
    var directories: [URL] = []

    if ProcessInfo.processInfo.arguments.contains("-hometeam_ui_testing") {
      directories.append(
        fileManager.temporaryDirectory
          .appendingPathComponent("HomeTeam-UITests", isDirectory: true)
          .appendingPathComponent(rootDirectoryName, isDirectory: true)
          .appendingPathComponent(logoDirectoryName, isDirectory: true)
      )
    }

    if let overrideRoot = sharedContainerOverrideRootURL {
      directories.append(
        overrideRoot
          .appendingPathComponent(rootDirectoryName, isDirectory: true)
          .appendingPathComponent(logoDirectoryName, isDirectory: true)
      )
      return uniqueURLs(directories)
    }

    if allowsProcessLocalFallback {
      if let appSupportRoot = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        directories.append(
          appSupportRoot
            .appendingPathComponent(rootDirectoryName, isDirectory: true)
            .appendingPathComponent(logoDirectoryName, isDirectory: true)
        )
      }

      directories.append(
        fileManager.temporaryDirectory
          .appendingPathComponent(rootDirectoryName, isDirectory: true)
          .appendingPathComponent(logoDirectoryName, isDirectory: true)
      )
      return uniqueURLs(directories)
    }

    if let groupContainer = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
      directories.append(
        groupContainer
          .appendingPathComponent(rootDirectoryName, isDirectory: true)
          .appendingPathComponent(logoDirectoryName, isDirectory: true)
      )
      return uniqueURLs(directories)
    }

    return uniqueURLs(directories)
  }

  func cachedImage(for remoteURLString: String?, sport: SupportedSport? = nil) -> NSImage? {
    guard let remoteURLString else {
      return nil
    }

    let sportsInContext: Set<SupportedSport> = sport.map { Set([$0]) } ?? []

    for candidateURL in candidateLogoURLs(for: remoteURLString) {
      for directory in logoDirectoryURLs {
        let localURL = localFileURL(for: candidateURL, in: directory)
        if let image = readImage(at: localURL) {
          if candidateURL != remoteURLString {
            reportFallbackLogoSourceIssue(for: sportsInContext)
          }
          return image
        }
      }
    }

    return nil
  }

  func cachedImage(for remoteURLString: String?, teamAbbrev: String, sport: SupportedSport? = nil) -> NSImage? {
    if let image = cachedImage(for: remoteURLString, sport: sport) {
      return image
    }

    let canonicalURL = Self.canonicalLeagueLogoURL(forAbbrev: teamAbbrev)
    return cachedImage(for: canonicalURL, sport: sport)
  }

  func prefetchLogos(for games: [HomeTeamGame], sport: SupportedSport? = nil) async {
    let sportsInContext = sportsContext(for: games, fallbackSport: sport)
    var remoteURLs = Set(
      games.flatMap { game in
        let teamLogos = [game.homeLogoURL, game.awayLogoURL].compactMap { $0 }
        let racingLogos = game.racingResults?.compactMap(\.teamLogoURL) ?? []
        let providerLogos = game.streamingServices.compactMap { StreamingProviderLogoCatalog.logoURL(for: $0) }
        return teamLogos + racingLogos + providerLogos
      }
    )
    remoteURLs.formUnion(canonicalLeagueFallbackURLs(for: games))

    var usedFallbackSource = false
    var hadUnavailableLogos = false
    var unavailableLogoURLs: [String] = []
    await withTaskGroup(of: LogoSourceResolution.self) { group in
      for remoteURLString in remoteURLs {
        group.addTask {
          await resolveLogoSource(for: remoteURLString)
        }
      }

      for await resolution in group {
        switch resolution {
        case .fallback:
          usedFallbackSource = true
        case .unavailable(let remoteURLString):
          hadUnavailableLogos = true
          unavailableLogoURLs.append(remoteURLString)
        case .primary:
          break
        }
      }
    }

    if usedFallbackSource {
      reportFallbackLogoSourceIssue(for: sportsInContext)
    }

    if hadUnavailableLogos {
      let preview = unavailableLogoURLs
        .sorted()
        .prefix(3)
        .joined(separator: ", ")
      if preview.isEmpty {
        RuntimeIssueCenter.report("Failed to cache one or more remote logos.")
      } else {
        RuntimeIssueCenter.report("Failed to cache one or more remote logos: \(preview)")
      }
    }
  }

  private enum LogoSourceResolution {
    case primary
    case fallback
    case unavailable(String)
  }

  private func resolveLogoSource(for remoteURLString: String) async -> LogoSourceResolution {
    let candidates = candidateLogoURLs(for: remoteURLString)
    guard let primarySource = candidates.first else {
      return .unavailable(remoteURLString)
    }

    if hasCachedFile(forExactRemoteURL: primarySource) {
      return .primary
    }

    if await cacheRemoteLogo(at: primarySource) {
      return .primary
    }

    for fallbackSource in candidates.dropFirst() {
      if hasCachedFile(forExactRemoteURL: fallbackSource) {
        return .fallback
      }

      if await cacheRemoteLogo(at: fallbackSource) {
        return .fallback
      }
    }

    return .unavailable(primarySource)
  }

  private func hasCachedFile(forExactRemoteURL remoteURLString: String) -> Bool {
    for directory in logoDirectoryURLs {
      let localURL = localFileURL(for: remoteURLString, in: directory)
      if FileManager.default.fileExists(atPath: localURL.path) {
        return true
      }
    }

    return false
  }

  private func candidateLogoURLs(for remoteURLString: String) -> [String] {
    var ordered = [remoteURLString]
    var seen = Set(ordered)
    for variant in fallbackLogoURLVariants(for: remoteURLString) where seen.insert(variant).inserted {
      ordered.append(variant)
    }
    return ordered
  }

  private func fallbackLogoURLVariants(for remoteURLString: String) -> [String] {
    guard let components = URLComponents(string: remoteURLString), let host = components.host?.lowercased() else {
      return []
    }

    if host == "logo.clearbit.com" {
      let domain = components.path
        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        .lowercased()
      guard !domain.isEmpty else {
        return []
      }
      return ["https://www.google.com/s2/favicons?domain=\(domain)&sz=64"]
    }

    if host == "www.google.com", components.path == "/s2/favicons" {
      guard
        let domain = components.queryItems?.first(where: { $0.name == "domain" })?.value?
          .trimmingCharacters(in: .whitespacesAndNewlines),
        !domain.isEmpty
      else {
        return []
      }
      return ["https://logo.clearbit.com/\(domain.lowercased())"]
    }

    return []
  }

  private func readImage(at localURL: URL?) -> NSImage? {
    guard
      let localURL,
      let data = try? Data(contentsOf: localURL)
    else {
      return nil
    }

    return NSImage(data: data)
  }

  private func cacheRemoteLogo(at remoteURLString: String) async -> Bool {
    guard let remoteURL = URL(string: remoteURLString) else {
      return false
    }
    let targetDirectories = logoDirectoryURLs
    guard !targetDirectories.isEmpty else {
      RuntimeIssueCenter.report("Logo cache directory unavailable.")
      return false
    }

    do {
      let (data, response) = try await URLSession.shared.data(from: remoteURL)
      guard
        let http = response as? HTTPURLResponse,
        (200...299).contains(http.statusCode),
        NSImage(data: data) != nil
      else {
        return false
      }

      for directoryURL in targetDirectories {
        let localURL = localFileURL(for: remoteURLString, in: directoryURL)
        do {
          try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
          try data.write(to: localURL, options: [.atomic])
          return true
        } catch {
          continue
        }
      }

      return false
    } catch {
      return false
    }
  }

  private func localFileURL(for remoteURLString: String, in directoryURL: URL) -> URL {
    let hash = SHA256.hash(data: Data(remoteURLString.utf8))
      .map { String(format: "%02x", $0) }
      .joined()

    return directoryURL.appendingPathComponent(hash).appendingPathExtension("img")
  }

  private func reportFallbackLogoSourceIssue(for sports: Set<SupportedSport>) {
    RuntimeIssueCenter.report(fallbackLogoIssueMessage(for: sports))
  }

  private func fallbackLogoIssueMessage(for sports: Set<SupportedSport>) -> String {
    guard !sports.isEmpty else {
      return "Using fallback logo source URL for one or more teams/providers."
    }

    let labels = sports.map(\.displayName).sorted().joined(separator: ", ")
    return "Using fallback logo source URL for one or more teams/providers in \(labels)."
  }

  private func sportsContext(for games: [HomeTeamGame], fallbackSport: SupportedSport?) -> Set<SupportedSport> {
    let sports = Set(games.compactMap(\.sport))
    if !sports.isEmpty {
      return sports
    }

    if let fallbackSport {
      return Set([fallbackSport])
    }

    return []
  }

  private var sharedContainerOverrideRootURL: URL? {
    guard
      let rawValue = ProcessInfo.processInfo.environment[sharedContainerOverrideEnvironmentKey]?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      !rawValue.isEmpty
    else {
      return nil
    }
    return URL(fileURLWithPath: rawValue, isDirectory: true)
  }

  private func uniqueURLs(_ urls: [URL]) -> [URL] {
    var seen = Set<String>()
    var ordered: [URL] = []
    for url in urls {
      let key = url.standardizedFileURL.path
      if seen.insert(key).inserted {
        ordered.append(url)
      }
    }
    return ordered
  }

  private var allowsProcessLocalFallback: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  }

  private func canonicalLeagueFallbackURLs(for games: [HomeTeamGame]) -> Set<String> {
    var fallbackURLs: Set<String> = []

    for game in games {
      guard game.sport == .nhl else {
        continue
      }

      if
        (game.homeLogoURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
        let fallback = Self.canonicalLeagueLogoURL(forAbbrev: game.homeAbbrev)
      {
        fallbackURLs.insert(fallback)
      }

      if
        (game.awayLogoURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
        let fallback = Self.canonicalLeagueLogoURL(forAbbrev: game.awayAbbrev)
      {
        fallbackURLs.insert(fallback)
      }
    }

    return fallbackURLs
  }

  private static func canonicalLeagueLogoURL(forAbbrev abbrev: String) -> String? {
    let normalized = abbrev.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalized.isEmpty else {
      return nil
    }

    let upper = normalized.uppercased()
    guard nhlAbbreviations.contains(upper) else {
      return nil
    }

    return "https://a.espncdn.com/i/teamlogos/nhl/500-dark/\(normalized).png"
  }
}
