import SwiftUI
import WidgetKit

let widgetAppGroupID = "group.com.jonzanoff.hometeam"
let widgetSmokeTestFileName = "smoke_test.json"

struct SmokePayload: Codable {
  let source: String
  let timestamp: String
}

struct SmokeEntry: TimelineEntry {
  let date: Date
  let source: String
  let timestamp: String
  let containerPath: String
}

struct SmokeProvider: TimelineProvider {
  func placeholder(in context: Context) -> SmokeEntry {
    SmokeEntry(date: Date(), source: "placeholder", timestamp: "–", containerPath: "–")
  }

  func getSnapshot(in context: Context, completion: @escaping (SmokeEntry) -> Void) {
    completion(makeEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SmokeEntry>) -> Void) {
    let entry = makeEntry()
    let refresh = Calendar.current.date(byAdding: .minute, value: 1, to: Date())!
    completion(Timeline(entries: [entry], policy: .after(refresh)))
  }

  private func makeEntry() -> SmokeEntry {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: widgetAppGroupID
    ) else {
      return SmokeEntry(date: Date(), source: "FAIL", timestamp: "containerURL is nil", containerPath: "nil")
    }

    let fileURL = container.appendingPathComponent(widgetSmokeTestFileName)

    guard
      let data = try? Data(contentsOf: fileURL),
      let payload = try? JSONDecoder().decode(SmokePayload.self, from: data)
    else {
      return SmokeEntry(date: Date(), source: "No data yet", timestamp: "Run SmokeApp first", containerPath: container.path)
    }

    return SmokeEntry(date: Date(), source: payload.source, timestamp: payload.timestamp, containerPath: container.path)
  }
}

struct SmokeWidgetView: View {
  let entry: SmokeEntry

  var isWorking: Bool { entry.source == "SmokeApp" }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("App Group Smoke")
        .font(.caption.weight(.bold))

      if isWorking {
        Label("SHARED OK", systemImage: "checkmark.circle.fill")
          .foregroundStyle(.green)
          .font(.caption.weight(.semibold))
      } else {
        Label(entry.source, systemImage: "xmark.circle.fill")
          .foregroundStyle(.red)
          .font(.caption.weight(.semibold))
      }

      Text("Written by: \(entry.source)")
        .font(.caption2)
      Text("At: \(entry.timestamp)")
        .font(.caption2)
        .lineLimit(2)
      Text("Container: \(entry.containerPath)")
        .font(.system(size: 8, design: .monospaced))
        .lineLimit(2)
        .foregroundStyle(.secondary)
    }
    .padding(8)
    .containerBackground(.black, for: .widget)
  }
}

struct SmokeWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "SmokeWidget", provider: SmokeProvider()) { entry in
      SmokeWidgetView(entry: entry)
    }
    .configurationDisplayName("App Group Smoke")
    .description("Shows data written by SmokeApp via shared App Group container.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
