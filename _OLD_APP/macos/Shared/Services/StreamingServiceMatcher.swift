import Foundation

enum StreamingServiceMatcher {
  private static let huluTVPattern = regex(#"\bHULU\b(\s*(\+|PLUS)\s*)?(\bLIVE\b\s*)?\bTV\b|\bHULU\b.*\bLIVE\b"#)

  private static let matchers: [(String, NSRegularExpression)] = [
    ("Hulu TV", huluTVPattern),
    ("Hulu", regex("\\bHULU\\b")),
    ("ESPN+", regex("\\bESPN\\s*\\+\\b")),
    ("Paramount", regex("\\bPARAMOUNT\\+?\\b")),
    ("Amazon", regex("\\b(AMAZON|PRIME)\\b")),
    ("Peacock", regex("\\bPEACOCK\\b")),
    ("HBO", regex("\\b(HBO|MAX|TNT|TBS|TRUTV|TRU\\s*TV)\\b|BLEACHER\\s+REPORT|\\bB/R\\b|\\bBR\\s*SPORTS\\b")),
    ("Apple TV", regex("\\bAPPLE\\s*TV(?:\\+)?\\b|\\bTV\\+|\\bAPPLETV\\+?\\b")),
    ("YouTube TV", regex("\\bYOUTUBE\\s*TV\\b")),
    ("Netflix", regex("\\bNETFLIX\\b")),
  ]

  static func matchedServices(from labels: [String]) -> [String] {
    var results: [String] = []

    for label in labels {
      let isHuluTV = firstMatch(huluTVPattern, in: label)

      for (service, pattern) in matchers where firstMatch(pattern, in: label) {
        if service == "Hulu", isHuluTV {
          continue
        }

        if !results.contains(service) {
          results.append(service)
        }
      }
    }

    return results
  }

  private static func regex(_ pattern: String) -> NSRegularExpression {
    try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
  }

  private static func firstMatch(_ regex: NSRegularExpression, in text: String) -> Bool {
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return regex.firstMatch(in: text, options: [], range: range) != nil
  }
}
