import SwiftUI

// MARK: - Menu bar icon + live status dot

struct MenuBarIcon: View {
  @EnvironmentObject var repository: ScheduleRepository

  var body: some View {
    HStack(spacing: 2) {
      Image(systemName: "sportscourt.fill")
        
        
        

      if liveCount > 0 {
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
