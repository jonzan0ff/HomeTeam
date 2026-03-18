import AppKit
import CryptoKit
import Foundation

struct SharedScheduleStore {
  private let directoryName = "CapsWidget"
  private let fileName = "schedule_snapshot.json"

  private var storeDirectoryURL: URL? {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent(directoryName)
  }

  private var storeURL: URL? {
    storeDirectoryURL?.appendingPathComponent(fileName)
  }

  func load() -> ScheduleSnapshot? {
    guard let storeURL else {
      return nil
    }

    guard let data = try? Data(contentsOf: storeURL) else {
      return nil
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try? decoder.decode(ScheduleSnapshot.self, from: data)
  }

  func save(_ snapshot: ScheduleSnapshot) throws {
    guard let storeDirectoryURL else {
      return
    }

    try FileManager.default.createDirectory(at: storeDirectoryURL, withIntermediateDirectories: true)

    guard let storeURL else {
      return
    }

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted]
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(snapshot)
    try data.write(to: storeURL, options: [.atomic])
  }
}

struct TeamLogoStore {
  private let rootDirectoryName = "CapsWidget"
  private let logoDirectoryName = "team_logos"
  private static let canonicalLeagueAbbreviations: [String] = [
    "ANA", "BOS", "BUF", "CGY", "CAR", "CHI", "COL", "CBJ",
    "DAL", "DET", "EDM", "FLA", "LAK", "MIN", "MTL", "NSH",
    "NJD", "NYI", "NYR", "OTT", "PHI", "PIT", "SEA", "SJS",
    "STL", "TBL", "TOR", "UTA", "VAN", "VGK", "WSH", "WPG",
    "ARI",
  ]

  private var logoDirectoryURL: URL? {
    guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return nil
    }

    return root
      .appendingPathComponent(rootDirectoryName, isDirectory: true)
      .appendingPathComponent(logoDirectoryName, isDirectory: true)
  }

  func cachedImage(for remoteURLString: String?) -> NSImage? {
    readImage(at: remoteURLString.flatMap(localFileURL(for:)))
  }

  func cachedImage(for remoteURLString: String?, teamAbbrev: String) -> NSImage? {
    if let image = cachedImage(for: remoteURLString) {
      return image
    }

    let canonicalURL = Self.canonicalLeagueLogoURL(forAbbrev: teamAbbrev)
    return readImage(at: canonicalURL.flatMap(localFileURL(for:)))
  }

  func prefetchLogos(for games: [CapsGame]) async {
    var remoteURLs = Set(
      games.flatMap { game in
        [game.homeLogoURL, game.awayLogoURL].compactMap { $0 }
      }
    )
    remoteURLs.formUnion(Self.canonicalLeagueLogoURLs)

    await withTaskGroup(of: Void.self) { group in
      for remoteURLString in remoteURLs {
        if hasCachedFile(for: remoteURLString) {
          continue
        }

        group.addTask {
          await cacheRemoteLogo(at: remoteURLString)
        }
      }
    }
  }

  private func hasCachedFile(for remoteURLString: String) -> Bool {
    guard let localURL = localFileURL(for: remoteURLString) else {
      return false
    }

    return FileManager.default.fileExists(atPath: localURL.path)
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

  private func cacheRemoteLogo(at remoteURLString: String) async {
    guard
      let remoteURL = URL(string: remoteURLString),
      let localURL = localFileURL(for: remoteURLString)
    else {
      return
    }

    do {
      let (data, response) = try await URLSession.shared.data(from: remoteURL)
      guard
        let http = response as? HTTPURLResponse,
        (200...299).contains(http.statusCode),
        NSImage(data: data) != nil
      else {
        return
      }

      try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try data.write(to: localURL, options: [.atomic])
    } catch {
      return
    }
  }

  private func localFileURL(for remoteURLString: String) -> URL? {
    guard let logoDirectoryURL else {
      return nil
    }

    let hash = SHA256.hash(data: Data(remoteURLString.utf8))
      .map { String(format: "%02x", $0) }
      .joined()

    return logoDirectoryURL.appendingPathComponent(hash).appendingPathExtension("img")
  }

  private static var canonicalLeagueLogoURLs: [String] {
    canonicalLeagueAbbreviations.compactMap(canonicalLeagueLogoURL(forAbbrev:))
  }

  private static func canonicalLeagueLogoURL(forAbbrev abbrev: String) -> String? {
    let normalized = abbrev.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !normalized.isEmpty else {
      return nil
    }

    return "https://a.espncdn.com/i/teamlogos/nhl/500-dark/\(normalized).png"
  }
}
