import SwiftUI

// MARK: - Menu bar icon + live status dot + update indicator

struct MenuBarIcon: View {
  @EnvironmentObject var repository: ScheduleRepository
  @EnvironmentObject var appState: AppState

  var body: some View {
    HStack(spacing: 2) {
      Image(systemName: "sportscourt.fill")

      if appState.isInstallingUpdate {
        // Orange progress ring during install
        ProgressRingView(progress: appState.updateProgress)
          .frame(width: 10, height: 10)
      } else if appState.availableUpdate != nil {
        // Orange dot when update available
        Circle()
          .fill(Color.orange)
          .frame(width: 6, height: 6)
      } else if liveCount > 0 {
        Circle()
          .fill(Color.green)
          .frame(width: 6, height: 6)
      }
    }
  }

  private var liveCount: Int {
    repository.snapshot.games.filter { $0.status == .live }.count
  }
}

// MARK: - Progress ring for update install

private struct ProgressRingView: View {
  let progress: Double

  var body: some View {
    ZStack {
      Circle()
        .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
      Circle()
        .trim(from: 0, to: progress)
        .stroke(Color.orange, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
  }
}
