import Foundation

// MARK: - App settings (persisted via App Group JSON + iCloud KV store)

struct AppSettings: Codable, Equatable {
  var selectedStreamingServices: [String]   // canonical keys from StreamingServiceMatcher
  var zipCode: String
  var favoriteTeamCompositeIDs: [String]
  var hideDuringOffseasonTeamCompositeIDs: [String]
  var notifications: AppNotificationSettings

  static let `default` = AppSettings(
    selectedStreamingServices: [],
    zipCode: "",
    favoriteTeamCompositeIDs: [],
    hideDuringOffseasonTeamCompositeIDs: [],
    notifications: .default
  )
}

// MARK: - Notification settings

struct AppNotificationSettings: Codable, Equatable {
  var gameStarting: Bool
  var scoreUpdates: Bool
  var finalScore: Bool

  static let `default` = AppNotificationSettings(
    gameStarting: true,
    scoreUpdates: false,
    finalScore: true
  )
}

// MARK: - Streaming provider catalog

struct StreamingProvider: Identifiable, Codable, Hashable {
  let canonicalKey: String    // matches StreamingServiceMatcher + logo filename stem
  let displayName: String

  var id: String { canonicalKey }

  // AsyncImage does not support SVG natively. GitHub Pages serves the SVGs
  // we downloaded; once PNG versions are added, update the extension here.
  var logoURL: URL? { nil }
}

enum StreamingProviderCatalog {
  static let all: [StreamingProvider] = [
    .init(canonicalKey: "espn",          displayName: "ESPN"),
    .init(canonicalKey: "espnplus",      displayName: "ESPN+"),
    .init(canonicalKey: "abc",           displayName: "ABC"),
    .init(canonicalKey: "netflix",       displayName: "Netflix"),
    .init(canonicalKey: "appletvplus",   displayName: "Apple TV+"),
    .init(canonicalKey: "primevideo",    displayName: "Prime Video"),
    .init(canonicalKey: "peacock",       displayName: "Peacock"),
    .init(canonicalKey: "paramountplus", displayName: "Paramount+"),
    .init(canonicalKey: "youtubetv",     displayName: "YouTube TV"),
    .init(canonicalKey: "hulu",          displayName: "Hulu"),
    .init(canonicalKey: "max",           displayName: "Max"),
    .init(canonicalKey: "tbs",           displayName: "TBS"),
    .init(canonicalKey: "fs1",           displayName: "FS1"),
    .init(canonicalKey: "fs2",           displayName: "FS2"),
    .init(canonicalKey: "fox",           displayName: "Fox"),
    .init(canonicalKey: "cbs",           displayName: "CBS"),
    .init(canonicalKey: "nbc",           displayName: "NBC"),
    .init(canonicalKey: "dazn",          displayName: "DAZN"),
    .init(canonicalKey: "f1tv",          displayName: "F1 TV"),
    .init(canonicalKey: "mlsseasonpass", displayName: "MLS Season Pass"),
  ]
}
