import Foundation

struct AppSettings: Codable, Equatable {
  var selectedStreamingServices: [String]
  var zipCode: String
  var city: String?
  var state: String?
  var notifications: AppNotificationSettings
  var favoriteTeamCompositeIDs: [String]
  var hideDuringOffseasonTeamCompositeIDs: [String]
  var recentTeamCompositeIDs: [String]

  static let `default` = AppSettings(
    selectedStreamingServices: [],
    zipCode: "",
    city: nil,
    state: nil,
    notifications: .default,
    favoriteTeamCompositeIDs: [],
    hideDuringOffseasonTeamCompositeIDs: [],
    recentTeamCompositeIDs: []
  )

  var selectedServiceLookup: Set<String> {
    Set(selectedStreamingServices.map(Self.normalizedServiceName))
  }

  var meetsOnboardingRequirements: Bool {
    !favoriteTeamCompositeIDs.isEmpty && !selectedStreamingServices.isEmpty
  }

  var locationSummary: String {
    guard
      let city,
      !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      let state,
      !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return "Not set"
    }

    return "\(city), \(state)"
  }

  static func normalizedServiceName(_ rawValue: String) -> String {
    let normalized = rawValue
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
      .replacingOccurrences(of: "+", with: " plus ")

    let tokens = normalized
      .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
      .map(String.init)

    let collapsed = tokens.joined(separator: " ")
    if collapsed.isEmpty {
      return ""
    }

    func has(_ token: String) -> Bool {
      tokens.contains(token)
    }

    if has("hulu"), has("tv") || has("live") {
      return "hulu tv"
    }
    if has("hulu") {
      return "hulu"
    }
    if has("espn") {
      return "espn+"
    }
    if has("paramount") {
      return "paramount"
    }
    if has("amazon") || has("prime") {
      return "amazon"
    }
    if has("peacock") {
      return "peacock"
    }
    if has("hbo") || has("max") || has("tnt") || has("tbs") || has("trutv") || (has("tru") && has("tv")) || (has("bleacher") && has("report")) || (has("br") && has("sports")) || (has("b") && has("r")) {
      return "hbo"
    }
    if collapsed.contains("appletv") || (has("apple") && (has("tv") || has("plus"))) {
      return "apple tv"
    }
    if has("youtube"), has("tv") {
      return "youtube tv"
    }
    if has("netflix") {
      return "netflix"
    }

    return collapsed
  }

  enum CodingKeys: String, CodingKey {
    case selectedStreamingServices
    case zipCode
    case city
    case state
    case notifications
    case favoriteTeamCompositeIDs
    case hideDuringOffseasonTeamCompositeIDs
    case recentTeamCompositeIDs
  }

  init(
    selectedStreamingServices: [String],
    zipCode: String,
    city: String?,
    state: String?,
    notifications: AppNotificationSettings,
    favoriteTeamCompositeIDs: [String],
    hideDuringOffseasonTeamCompositeIDs: [String],
    recentTeamCompositeIDs: [String]
  ) {
    self.selectedStreamingServices = selectedStreamingServices
    self.zipCode = zipCode
    self.city = city
    self.state = state
    self.notifications = notifications
    self.favoriteTeamCompositeIDs = Self.sanitizedTeamCompositeIDs(
      favoriteTeamCompositeIDs,
      fallback: []
    )
    self.hideDuringOffseasonTeamCompositeIDs = Self.sanitizedTeamCompositeIDs(hideDuringOffseasonTeamCompositeIDs)
    self.recentTeamCompositeIDs = Self.sanitizedTeamCompositeIDs(recentTeamCompositeIDs)
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    selectedStreamingServices = try container.decodeIfPresent([String].self, forKey: .selectedStreamingServices) ?? Self.default.selectedStreamingServices
    zipCode = try container.decodeIfPresent(String.self, forKey: .zipCode) ?? ""
    city = try container.decodeIfPresent(String.self, forKey: .city)
    state = try container.decodeIfPresent(String.self, forKey: .state)
    notifications = try container.decodeIfPresent(AppNotificationSettings.self, forKey: .notifications) ?? .default
    let decodedRecents = try container.decodeIfPresent([String].self, forKey: .recentTeamCompositeIDs) ?? []
    let decodedFavorites = try container.decodeIfPresent([String].self, forKey: .favoriteTeamCompositeIDs) ?? []
    let decodedOffseasonHides = try container.decodeIfPresent([String].self, forKey: .hideDuringOffseasonTeamCompositeIDs) ?? []

    favoriteTeamCompositeIDs = Self.sanitizedTeamCompositeIDs(decodedFavorites, fallback: [])
    hideDuringOffseasonTeamCompositeIDs = Self.sanitizedTeamCompositeIDs(decodedOffseasonHides)
    recentTeamCompositeIDs = Self.sanitizedTeamCompositeIDs(decodedRecents)
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(selectedStreamingServices, forKey: .selectedStreamingServices)
    try container.encode(zipCode, forKey: .zipCode)
    try container.encodeIfPresent(city, forKey: .city)
    try container.encodeIfPresent(state, forKey: .state)
    try container.encode(notifications, forKey: .notifications)
    try container.encode(favoriteTeamCompositeIDs, forKey: .favoriteTeamCompositeIDs)
    try container.encode(hideDuringOffseasonTeamCompositeIDs, forKey: .hideDuringOffseasonTeamCompositeIDs)
    try container.encode(recentTeamCompositeIDs, forKey: .recentTeamCompositeIDs)
  }

  private static func sanitizedTeamCompositeIDs(_ rawIDs: [String], fallback: [String] = []) -> [String] {
    var seen = Set<String>()
    var ordered: [String] = []

    for rawID in rawIDs {
      guard let compositeID = TeamCatalog.canonicalCompositeID(for: rawID) else {
        continue
      }
      if seen.insert(compositeID).inserted {
        ordered.append(compositeID)
      }
    }

    if !ordered.isEmpty {
      return ordered
    }

    for rawID in fallback {
      guard let compositeID = TeamCatalog.canonicalCompositeID(for: rawID) else {
        continue
      }
      if seen.insert(compositeID).inserted {
        ordered.append(compositeID)
      }
    }

    return ordered
  }
}

struct AppNotificationSettings: Codable, Equatable {
  var gameStartReminders: Bool
  var finalScores: Bool

  static let `default` = AppNotificationSettings(
    gameStartReminders: true,
    finalScores: true
  )

  enum CodingKeys: String, CodingKey {
    case gameStartReminders
    case finalScores
    case watchableGamesOnly
  }

  init(gameStartReminders: Bool, finalScores: Bool) {
    self.gameStartReminders = gameStartReminders
    self.finalScores = finalScores
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    gameStartReminders = try container.decodeIfPresent(Bool.self, forKey: .gameStartReminders) ?? true
    finalScores = try container.decodeIfPresent(Bool.self, forKey: .finalScores) ?? true
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(gameStartReminders, forKey: .gameStartReminders)
    try container.encode(finalScores, forKey: .finalScores)
  }
}

struct StreamingProvider: Identifiable, Codable, Hashable {
  let id: String
  let name: String
}

enum StreamingProviderCatalog {
  static let providers: [StreamingProvider] = [
    .init(id: "hulu", name: "Hulu"),
    .init(id: "hulu-tv", name: "Hulu TV"),
    .init(id: "espn-plus", name: "ESPN+"),
    .init(id: "paramount", name: "Paramount"),
    .init(id: "amazon", name: "Amazon"),
    .init(id: "peacock", name: "Peacock"),
    .init(id: "hbo", name: "HBO"),
    .init(id: "apple-tv", name: "Apple TV"),
    .init(id: "youtube-tv", name: "YouTube TV"),
    .init(id: "netflix", name: "Netflix"),
  ]
}

enum StreamingProviderLogoCatalog {
  static func logoURL(for serviceName: String) -> String? {
    let normalized = AppSettings.normalizedServiceName(serviceName)

    if normalized.contains("hulu tv") || normalized.contains("hulu live") {
      return faviconURL(domain: "hulu.com")
    }
    if normalized.contains("hulu") {
      return faviconURL(domain: "hulu.com")
    }
    if normalized.contains("espn") {
      return faviconURL(domain: "espn.com")
    }
    if normalized.contains("paramount") {
      return faviconURL(domain: "paramountplus.com")
    }
    if normalized.contains("amazon") || normalized.contains("prime") {
      return faviconURL(domain: "primevideo.com")
    }
    if normalized.contains("peacock") {
      return faviconURL(domain: "peacocktv.com")
    }
    if normalized.contains("hbo") || normalized.contains("max") {
      return faviconURL(domain: "hbo.com")
    }
    if normalized.contains("apple") {
      return faviconURL(domain: "tv.apple.com")
    }
    if normalized.contains("youtube") {
      return faviconURL(domain: "tv.youtube.com")
    }
    if normalized.contains("netflix") {
      return faviconURL(domain: "netflix.com")
    }

    return nil
  }

  private static func faviconURL(domain: String) -> String {
    "https://www.google.com/s2/favicons?domain=\(domain)&sz=64"
  }
}
