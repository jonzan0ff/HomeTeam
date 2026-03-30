import SwiftUI

let appGroupID = "group.com.hometeam.shared"
let smokeTestFileName = "smoke_test.json"

struct SmokePayload: Codable {
  let source: String
  let timestamp: String
}

struct ContentView: View {
  @State private var writeResult: String = "Not attempted yet"
  @State private var readResult: String = "Not attempted yet"
  @State private var containerURL: String = "Unknown"

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("App Group Smoke Test")
        .font(.title.weight(.bold))

      Group {
        Label("App Group ID", systemImage: "folder").font(.headline)
        Text(appGroupID)
          .font(.system(.body, design: .monospaced))
          .foregroundStyle(.secondary)

        Label("Container URL", systemImage: "externaldrive").font(.headline)
        Text(containerURL)
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
      }

      Divider()

      Group {
        Label("Write result", systemImage: "pencil").font(.headline)
        Text(writeResult)
          .font(.system(.body, design: .monospaced))
          .foregroundStyle(writeResult.hasPrefix("OK") ? .green : .red)

        Label("Read back", systemImage: "doc.text.magnifyingglass").font(.headline)
        Text(readResult)
          .font(.system(.body, design: .monospaced))
          .foregroundStyle(readResult.hasPrefix("OK") ? .green : .red)
          .textSelection(.enabled)
      }

      Divider()

      Button("Run Smoke Test") { runSmokeTest() }
        .buttonStyle(.borderedProminent)

      Text("The widget reads the same file. If the widget shows the timestamp below, App Group sharing is confirmed end-to-end.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(24)
    .frame(minWidth: 560)
    .onAppear { runSmokeTest() }
  }

  private func runSmokeTest() {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: appGroupID
    ) else {
      containerURL = "nil — App Group not provisioned or entitlement missing"
      writeResult = "FAIL: containerURL is nil"
      readResult = "FAIL: cannot read without container"
      return
    }

    containerURL = container.path
    let fileURL = container.appendingPathComponent(smokeTestFileName)
    let iso = ISO8601DateFormatter().string(from: Date())
    let payload = SmokePayload(source: "SmokeApp", timestamp: iso)

    do {
      let data = try JSONEncoder().encode(payload)
      try data.write(to: fileURL, options: .atomic)
      writeResult = "OK — wrote \(data.count) bytes to \(smokeTestFileName)"
    } catch {
      writeResult = "FAIL: \(error.localizedDescription)"
      readResult = "Skipped (write failed)"
      return
    }

    do {
      let data = try Data(contentsOf: fileURL)
      let decoded = try JSONDecoder().decode(SmokePayload.self, from: data)
      readResult = "OK — source: \(decoded.source), timestamp: \(decoded.timestamp)"
    } catch {
      readResult = "FAIL: \(error.localizedDescription)"
    }
  }
}
