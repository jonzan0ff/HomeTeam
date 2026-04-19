import AppKit
import SwiftUI
import Combine

// MARK: - Menu bar controller (NSStatusItem + NSPopover)
// Replaces SwiftUI MenuBarExtra which doesn't support reactive label updates.
// Matches the pattern used by What to Watch.

@MainActor
final class MenuBarController: NSObject {
  static let shared = MenuBarController()

  private var statusItem: NSStatusItem?
  private var popover: NSPopover?
  private var eventMonitor: Any?
  private var escapeMonitor: Any?
  private var cancellables = Set<AnyCancellable>()

  private override init() {
    super.init()
  }

  func install() {
    guard statusItem == nil else { return }
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    self.statusItem = item

    guard let button = item.button else { return }
    button.image = NSImage(systemSymbolName: "sportscourt.fill", accessibilityDescription: "HomeTeam")
    button.toolTip = "Last synced 00:00"
    button.target = self
    button.action = #selector(togglePopover(_:))

    // Create popover with SwiftUI content
    let popover = NSPopover()
    popover.behavior = .transient
    popover.delegate = self
    popover.contentViewController = NSHostingController(
      rootView: MenuBarContentView()
        .environmentObject(AppSettingsStore.shared)
        .environmentObject(ScheduleRepository.shared)
        .environmentObject(AppState.shared)
    )
    self.popover = popover

    // Observe update state
    AppState.shared.$availableUpdate
      .receive(on: DispatchQueue.main)
      .sink { [weak self] update in
        guard let self, !AppState.shared.isInstallingUpdate else { return }
        self.showUpdateAvailable(update != nil)
      }
      .store(in: &cancellables)

    AppState.shared.$isInstallingUpdate
      .receive(on: DispatchQueue.main)
      .sink { [weak self] installing in
        guard let self else { return }
        if installing {
          self.showUpdateProgress(AppState.shared.updateProgress)
        } else {
          self.showUpdateAvailable(AppState.shared.availableUpdate != nil)
        }
      }
      .store(in: &cancellables)

    AppState.shared.$updateProgress
      .receive(on: DispatchQueue.main)
      .sink { [weak self] progress in
        guard let self, AppState.shared.isInstallingUpdate else { return }
        self.showUpdateProgress(progress)
      }
      .store(in: &cancellables)

    // Observe live game state
    ScheduleRepository.shared.objectWillChange
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        DispatchQueue.main.async {
          guard let self,
                AppState.shared.availableUpdate == nil,
                !AppState.shared.isInstallingUpdate else { return }
          let hasLive = ScheduleRepository.shared.snapshot.games.contains { $0.status == .live }
          self.showLiveDot(hasLive)
        }
      }
      .store(in: &cancellables)
  }

  // MARK: - Popover

  @objc private func togglePopover(_ sender: NSStatusBarButton) {
    if let popover, popover.isShown {
      popover.performClose(sender)
    } else {
      popover?.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
      // Close popover when clicking outside
      eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
        self?.popover?.performClose(nil)
      }
    }
  }

  // MARK: - Indicators (matches What to Watch pattern)

  func showUpdateAvailable(_ available: Bool) {
    rebuildButton(dot: available ? .orange : nil)
  }

  func showUpdateProgress(_ progress: Double) {
    rebuildButton(dot: nil, progress: progress)
  }

  func showLiveDot(_ visible: Bool) {
    rebuildButton(dot: visible ? .green : nil)
  }

  private enum DotColor { case orange, green }

  private func rebuildButton(dot: DotColor? = nil, progress: Double? = nil) {
    guard let button = statusItem?.button else { return }

    button.subviews.forEach { $0.removeFromSuperview() }

    let iconImage = NSImage(systemSymbolName: "sportscourt.fill", accessibilityDescription: "HomeTeam")
    let iconWidth: CGFloat = iconImage?.size.width ?? 18

    if let progress {
      let ringSize: CGFloat = 10
      let gap: CGFloat = 2
      button.image = iconImage
      let ring = ProgressRingView(frame: NSRect(
        x: iconWidth + gap,
        y: (button.bounds.height - ringSize) / 2,
        width: ringSize, height: ringSize
      ))
      ring.progress = progress
      button.addSubview(ring)
      statusItem?.length = iconWidth + gap + ringSize + 6
    } else if let dot {
      let dotSize: CGFloat = 6
      let color: NSColor = dot == .orange ? .systemOrange : .systemGreen
      button.image = iconImage
      let dotView = NSView(frame: NSRect(
        x: iconWidth - dotSize / 2,
        y: 14,
        width: dotSize, height: dotSize
      ))
      dotView.wantsLayer = true
      dotView.layer?.backgroundColor = color.cgColor
      dotView.layer?.cornerRadius = dotSize / 2
      button.addSubview(dotView)
      statusItem?.length = iconWidth + dotSize / 2 + 2
    } else {
      button.image = iconImage
      statusItem?.length = NSStatusItem.variableLength
    }
  }

  // MARK: - Escape dismissal

  fileprivate func installEscapeMonitor() {
    guard escapeMonitor == nil else { return }
    escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      if event.keyCode == 53 { // Escape
        self?.popover?.performClose(nil)
        return nil
      }
      return event
    }
  }

  fileprivate func removeEscapeMonitor() {
    if let monitor = escapeMonitor {
      NSEvent.removeMonitor(monitor)
      escapeMonitor = nil
    }
  }
}

// MARK: - NSPopoverDelegate

extension MenuBarController: NSPopoverDelegate {
  nonisolated func popoverDidShow(_ notification: Notification) {
    Task { @MainActor in self.installEscapeMonitor() }
  }

  nonisolated func popoverDidClose(_ notification: Notification) {
    Task { @MainActor in self.removeEscapeMonitor() }
  }
}

// MARK: - Progress Ring

final class ProgressRingView: NSView {
  var progress: Double = 0

  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
    let inset: CGFloat = 0.5
    let rect = bounds.insetBy(dx: inset, dy: inset)
    let center = NSPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    let lineWidth: CGFloat = 1.5

    let bgPath = NSBezierPath()
    bgPath.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
    bgPath.lineWidth = lineWidth
    NSColor.systemOrange.withAlphaComponent(0.3).setStroke()
    bgPath.stroke()

    guard progress > 0 else { return }
    let startAngle: CGFloat = 90
    let endAngle = startAngle - CGFloat(progress) * 360
    let arcPath = NSBezierPath()
    arcPath.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
    arcPath.lineWidth = lineWidth
    arcPath.lineCapStyle = .round
    NSColor.systemOrange.setStroke()
    arcPath.stroke()
  }
}
