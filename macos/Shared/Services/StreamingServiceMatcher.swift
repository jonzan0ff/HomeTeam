import Foundation

// MARK: - Streaming service name normalization
// Maps raw provider strings (from ESPN API, user input) to canonical keys.
// Canonical keys match filenames in logos/streaming/ without extension.

enum StreamingServiceMatcher {

  /// Returns the canonical service key for `rawName`, or nil if no match.
  static func canonicalKey(for rawName: String) -> String? {
    let normalized = rawName
      .lowercased()
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "+", with: "plus")
      .components(separatedBy: .whitespaces).joined()

    return lookupTable[normalized]
  }

  /// Returns true if `rawName` matches any canonical key in `selectedKeys`.
  static func isMatch(rawName: String, selectedKeys: Set<String>) -> Bool {
    guard let key = canonicalKey(for: rawName) else { return false }
    return selectedKeys.contains(key)
  }

  // MARK: - Lookup table
  // Key: normalized raw string  Value: canonical key (= logo filename stem)
  private static let lookupTable: [String: String] = [
    // ESPN / ABC
    "espn": "espn",
    "espn+": "espnplus",
    "espnplus": "espnplus",
    "espn2": "espn2",
    "abc": "abc",
    // Netflix
    "netflix": "netflix",
    // Apple TV+
    "appletv+": "appletvplus",
    "appletv": "appletvplus",
    "appletvplus": "appletvplus",
    "apple tv+": "appletvplus",
    "apple tv": "appletvplus",
    // Amazon / Prime Video
    "primevideo": "primevideo",
    "amazonprimevideo": "primevideo",
    "amazon": "primevideo",
    // Peacock
    "peacock": "peacock",
    "peacockpremium": "peacock",
    // Paramount+
    "paramount+": "paramountplus",
    "paramountplus": "paramountplus",
    // YouTube TV
    "youtubetv": "youtubetv",
    // Hulu
    "hulu": "hulu",
    // MAX / HBO Max / TNT (TNT sports content streams on Max)
    "max": "max",
    "hbomax": "max",
    "tnt": "max",
    // TBS
    "tbs": "tbs",
    // FS1 / FS2 / Fox Sports
    "fs1": "fs1",
    "foxsports1": "fs1",
    "fs2": "fs2",
    "foxsports2": "fs2",
    "fox": "fox",
    // CBS / Paramount
    "cbs": "cbs",
    "cbssports": "cbs",
    // NBC
    "nbc": "nbc",
    "nbcsports": "nbc",
    // DAZN
    "dazn": "dazn",
    // MLB.TV
    "mlb.tv": "mlbtv",
    "mlbtv": "mlbtv",
    // NHL.TV / ESPN+
    "nhl.tv": "espnplus",
    // NFL+
    "nfl+": "nflplus",
    "nflplus": "nflplus",
    // NBA League Pass
    "nba league pass": "nbaleaguepass",
    "nbaleaguepass": "nbaleaguepass",
    // F1 TV
    "f1 tv": "f1tv",
    "f1tv": "f1tv",
    "f1 tv pro": "f1tv",
    // MLS Season Pass
    "mls season pass": "mlsseasonpass",
    "mlsseasonpass": "mlsseasonpass",
  ]
}
