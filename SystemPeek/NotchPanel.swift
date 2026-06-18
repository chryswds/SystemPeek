import AppKit
import SwiftUI
import Combine

/// A borderless, non-activating panel pinned under the notch. Hidden by default;
/// hovering the notch reveals the metrics. While music is playing it instead shows
/// an extended "music strip" (artwork + pulse) and the hover zone becomes that
/// wider strip. Hover is detected by polling the cursor position.
final class NotchPanel: NSPanel {

    private let sampler: MetricsSampler
    private let monitor: NowPlayingMonitor
    private let state = PanelState()
    private let panelTopInset: CGFloat
    private let onOpenSettings: (() -> Void)?
    private let notchSize: CGSize
    private let musicStripSize: CGSize
    private var expandedSize = NSSize(width: 480, height: 150)
    private var hoverTimer: Timer?
    private var isExpanded = false
    private var cancellables = Set<AnyCancellable>()

    init(sampler: MetricsSampler, monitor: NowPlayingMonitor, onOpenSettings: (() -> Void)? = nil) {
        self.sampler = sampler
        self.monitor = monitor
        self.onOpenSettings = onOpenSettings
        let inset = NotchPanel.notchScreen()
            .map { max($0.safeAreaInsets.top, $0.frame.maxY - $0.visibleFrame.maxY) } ?? 32
        self.panelTopInset = inset
        let notchW = NotchPanel.notchScreen().map { max(NotchPanel.notchRect(on: $0).width, 120) } ?? 180
        self.notchSize = CGSize(width: notchW, height: inset)
        self.musicStripSize = CGSize(width: notchW + MusicStripView.sideExtension * 2, height: inset)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        expandedSize = NotchPanel.measureIsland(sampler: sampler, topInset: inset)
        state.islandSize = expandedSize
        state.collapsedSize = notchSize

        let hosting = NSHostingView(rootView: NotchContentView(
            sampler: sampler, state: state, monitor: monitor, topInset: inset, notchSize: notchSize
        ))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let menu = NSMenu()
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit SystemPeek",
                     action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        hosting.menu = menu
        contentView = container

        setFrame(expandedFrame(), display: false)   // hidden until hover / music
        startHoverTracking()

        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: UserDefaults.didChangeNotification, object: nil
        )

        // Enter/exit music mode as playback starts/stops.
        monitor.$info
            .map { $0 != nil }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] playing in
                if playing { self?.enterMusicMode() } else { self?.exitMusicMode() }
            }
            .store(in: &cancellables)
    }

    @objc private func openSettings() { onOpenSettings?() }

    @objc private func settingsChanged() {
        let size = NotchPanel.measureIsland(sampler: sampler, topInset: panelTopInset)
        guard size != expandedSize else { return }
        expandedSize = size
        state.islandSize = size
        if isExpanded { setFrame(expandedFrame(), display: true) }
    }

    private static func measureIsland(sampler: MetricsSampler, topInset: CGFloat) -> NSSize {
        let host = NSHostingView(rootView: ExpandedView(sampler: sampler, topInset: topInset))
        host.layoutSubtreeIfNeeded()
        let size = host.fittingSize
        return (size.width > 1 && size.height > 1) ? size : NSSize(width: 480, height: 150)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func reposition() {
        if isExpanded { setFrame(expandedFrame(), display: true) }
        else if state.musicMode { setFrame(collapsedWindowFrame(), display: true) }
    }

    // MARK: - Music mode

    private func enterMusicMode() {
        state.musicMode = true
        state.collapsedSize = musicStripSize
        if !isExpanded {
            alphaValue = 1
            setFrame(collapsedWindowFrame(), display: true)
            orderFrontRegardless()
        }
    }

    private func exitMusicMode() {
        state.musicMode = false
        state.collapsedSize = notchSize
        if !isExpanded { orderOut(nil) }
    }

    // MARK: - Hover (cursor-position polling)

    private func startHoverTracking() {
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateHover() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    private func updateHover() {
        guard let screen = NotchPanel.notchScreen() else { return }
        let mouse = NSEvent.mouseLocation
        if isExpanded {
            if !keepOpenZone(on: screen).contains(mouse) { collapse() }
        } else if triggerZone(on: screen).contains(mouse) {
            expand()
        }
    }

    private func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        alphaValue = 1
        setFrame(expandedFrame(), display: false)
        orderFrontRegardless()
        state.isExpanded = true
    }

    private func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        state.isExpanded = false
        if state.musicMode {
            // Morph back to the strip, then shrink the window to the strip height.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self, !self.isExpanded, self.state.musicMode else { return }
                self.setFrame(self.collapsedWindowFrame(), display: true)
            }
        } else {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard let self, !self.isExpanded else { return }
                self.orderOut(nil)
                self.alphaValue = 1
            })
        }
    }

    // MARK: - Frames & zones

    private func topInset(on screen: NSScreen) -> CGFloat {
        max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY)
    }

    private let topOverscan: CGFloat = 8

    /// The hover trigger: the notch (plus a small margin) normally, or the wider
    /// music strip while music is playing.
    private func triggerZone(on screen: NSScreen) -> NSRect {
        let notch = NotchPanel.notchRect(on: screen)
        let inset = topInset(on: screen)
        let width = state.musicMode ? musicStripSize.width : max(notch.width, 120) + 40
        let bottom = screen.frame.maxY - inset - 8
        return NSRect(x: notch.midX - width / 2, y: bottom,
                      width: width, height: screen.frame.maxY + topOverscan - bottom)
    }

    private func keepOpenZone(on screen: NSScreen) -> NSRect {
        let notch = NotchPanel.notchRect(on: screen)
        let panel = expandedFrame()
        let width = max(panel.width, notch.width)
        return NSRect(x: notch.midX - width / 2, y: panel.minY,
                      width: width, height: screen.frame.maxY + topOverscan - panel.minY)
    }

    /// Revealed (metrics) frame, anchored to the top of the screen.
    private func expandedFrame() -> NSRect {
        guard let screen = NotchPanel.notchScreen() else { return frame }
        let notch = NotchPanel.notchRect(on: screen)
        return NSRect(x: notch.midX - expandedSize.width / 2,
                      y: screen.frame.maxY - expandedSize.height,
                      width: expandedSize.width, height: expandedSize.height)
    }

    /// Collapsed window frame for music mode: full width (so it can grow in place)
    /// but only the strip's height, so it doesn't block clicks below.
    private func collapsedWindowFrame() -> NSRect {
        guard let screen = NotchPanel.notchScreen() else { return frame }
        let notch = NotchPanel.notchRect(on: screen)
        let h = state.collapsedSize.height
        return NSRect(x: notch.midX - expandedSize.width / 2,
                      y: screen.frame.maxY - h,
                      width: expandedSize.width, height: h)
    }

    deinit { hoverTimer?.invalidate() }

    // MARK: - Notch geometry

    static func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    static func notchRect(on screen: NSScreen) -> NSRect {
        let topInset = screen.safeAreaInsets.top
        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let minX = left.maxX
            let maxX = right.minX
            return NSRect(x: minX, y: screen.frame.maxY - topInset,
                          width: max(maxX - minX, 0), height: topInset)
        }
        return NSRect(x: screen.frame.midX - minimumWidthFallback / 2,
                      y: screen.frame.maxY, width: minimumWidthFallback, height: 0)
    }

    private static let minimumWidthFallback: CGFloat = 180
}

/// Shared reveal/music state driving the SwiftUI content.
@MainActor
final class PanelState: ObservableObject {
    @Published var isExpanded = false
    @Published var islandSize: CGSize = CGSize(width: 480, height: 150)
    @Published var collapsedSize: CGSize = CGSize(width: 180, height: 32)
    @Published var musicMode = false
}

/// The panel content: a black NotchShape that morphs between the collapsed size
/// (notch footprint, or the wider music strip) and the island, with the music
/// strip or the metrics shown on top.
private struct NotchContentView: View {
    @ObservedObject var sampler: MetricsSampler
    @ObservedObject var state: PanelState
    @ObservedObject var monitor: NowPlayingMonitor
    var topInset: CGFloat
    var notchSize: CGSize

    var body: some View {
        let island = state.islandSize
        let collapsed = state.collapsedSize
        let w = state.isExpanded ? island.width : collapsed.width
        let h = state.isExpanded ? island.height : collapsed.height
        // The thin music strip reads better with squarer bottom corners.
        let stripRadius: CGFloat = 10
        let bottomRadius: CGFloat = state.isExpanded ? 28 : (state.musicMode ? stripRadius : 28)
        ZStack(alignment: .top) {
            NotchShape(bottomCornerRadius: bottomRadius)
                .fill(Color.black)
                .frame(width: w, height: h)
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: state.isExpanded)
                .animation(.spring(response: 0.34, dampingFraction: 0.9), value: state.collapsedSize)

            if state.musicMode {
                // Stays visible as a header even when the metrics are expanded
                // (the metrics view's top padding is transparent, so it shows through).
                MusicStripView(monitor: monitor, notchWidth: notchSize.width, height: collapsed.height)
                    .frame(width: collapsed.width, height: collapsed.height, alignment: .top)
                    .clipShape(NotchShape(bottomCornerRadius: stripRadius))
            }

            ExpandedView(sampler: sampler, topInset: topInset)
                .frame(width: w, height: h, alignment: .top)
                .clipShape(NotchShape(bottomCornerRadius: bottomRadius))
                .opacity(state.isExpanded ? 1 : 0)
                .animation(.easeOut(duration: 0.08), value: state.isExpanded)
        }
        .frame(width: max(island.width, collapsed.width), height: island.height, alignment: .top)
    }
}
