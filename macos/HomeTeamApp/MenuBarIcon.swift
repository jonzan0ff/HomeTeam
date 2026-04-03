import SwiftUI

// MARK: - Menu bar icon + indicators
// MenuBarExtra labels have broken @ObservedObject reactivity — they don't
// re-render when published properties change. TimelineView forces periodic
// re-evaluation as a workaround.

struct MenuBarIcon: View {
  var body: some View {
    TimelineView(.periodic(from: .now, by: 5)) { _ in
      HStack(spacing: 2) {
        Image(systemName: "sportscourt.fill")

        if AppState.shared.availableUpdate != nil {
          Circle()
            .fill(Color.orange)
            .frame(width: 6, height: 6)
        } else if ScheduleRepository.shared.snapshot.games.contains(where: { $0.status == .live }) {
          Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
        }
      }
    }
  }
}
