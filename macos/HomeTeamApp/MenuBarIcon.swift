import SwiftUI

// MARK: - Menu bar icon + indicators

struct MenuBarIcon: View {
  @ObservedObject var repository = ScheduleRepository.shared
  @ObservedObject var appState = AppState.shared

  var body: some View {
    HStack(spacing: 2) {
      Image(systemName: "sportscourt.fill")

      if appState.availableUpdate != nil {
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
