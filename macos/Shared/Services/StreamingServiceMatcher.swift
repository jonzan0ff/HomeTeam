import Foundation

enum StreamingServiceMatcher {
  private static let matchers: [(String, NSRegularExpression)] = [
    ("Hulu", regex("\\bHULU\\b")),
    ("Paramount", regex("\\bPARAMOUNT\\+?\\b")),
    ("Amazon", regex("\\b(AMAZON|PRIME)\\b")),
    ("Peacock", regex("\\bPEACOCK\\b")),
    ("HBO", regex("\\b(HBO|MAX)\\b")),
    ("Apple TV", regex("\\bAPPLE\\s*TV|TV\\+\\b")),
    ("Netflix", regex("\\bNETFLIX\\b")),
  ]

  static func matchedServices(from labels: [String]) -> [String] {
    var results: [String] = []

    for label in labels {
      if shouldTreatAsEspnPlusOnly(label) {
        continue
      }

      for (service, pattern) in matchers where firstMatch(pattern, in: label) {
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

  private static func shouldTreatAsEspnPlusOnly(_ label: String) -> Bool {
    let uppercased = label.uppercased()
    return uppercased.contains("HULU") && uppercased.contains("ESPN+")
  }
}
