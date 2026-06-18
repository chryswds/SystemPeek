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
    private var expandedSize = NSSize(width: 480, height: 150)   // window size: fixed max height when expanded
    private var hoverTimer: Timer?
    private var isExpanded = false
    private var cancellables = Set<AnyCancellable>()
    private var scrollMonitor: Any?
    private var scrollAccum: CGFloat = 0

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

        // Both pages share one fixed island size (the taller of the two), so
        // swiping never resizes the island — no jump.
        let metrics = NotchPanel.measureIsland(sampler: sampler, topInset: inset)
        let islandWidth = max(metrics.width, 500)
        let islandHeight = max(metrics.height, inset + 200)
        expandedSize = CGSize(width: islandWidth, height: islandHeight)
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

        // Two-finger horizontal swipe over the expanded island flips pages.
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
            return event
        }

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

    private func handleScroll(_ event: NSEvent) {
        guard isExpanded,
              abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY),
              expandedFrame().contains(NSEvent.mouseLocation) else { return }
        if event.phase == .began { scrollAccum = 0 }
        scrollAccum += event.scrollingDeltaX
        if scrollAccum <= -38 { changePage(1); scrollAccum = 0 }       // swipe left -> next
        else if scrollAccum >= 38 { changePage(-1); scrollAccum = 0 }  // swipe right -> previous
        if event.phase == .ended || event.momentumPhase == .ended { scrollAccum = 0 }
    }

    private func changePage(_ delta: Int) {
        let target = max(0, min(1, state.currentPage + delta))
        guard target != state.currentPage else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { state.currentPage = target }
    }

    @objc private func openSettings() { onOpenSettings?() }

    @objc private func settingsChanged() {
        let metrics = NotchPanel.measureIsland(sampler: sampler, topInset: panelTopInset)
        let islandWidth = max(metrics.width, 500)
        let newSize = CGSize(width: islandWidth, height: max(metrics.height, panelTopInset + 200))
        guard newSize != expandedSize else { return }
        expandedSize = newSize
        state.islandSize = newSize
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
        state.currentPage = 0   // next reveal starts on the metrics page
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

    deinit {
        hoverTimer?.invalidate()
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
    }

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
    @Published var islandSize: CGSize = CGSize(width: 500, height: 230)  // fixed: both pages share this size
    @Published var collapsedSize: CGSize = CGSize(width: 180, height: 32)
    @Published var musicMode = false
    @Published var currentPage = 0   // 0 = metrics, 1 = music controls
}

/// The panel content: the black NotchShape morphs between collapsed (notch / music
/// strip) and the island. When expanded it hosts a 2-page pager (metrics + music
/// controls) with a hero album cover that flies between the header and the music page.
private struct NotchContentView: View {
    @ObservedObject var sampler: MetricsSampler
    @ObservedObject var state: PanelState
    @ObservedObject var monitor: NowPlayingMonitor
    var topInset: CGFloat
    var notchSize: CGSize

    @State private var drag: CGFloat = 0
    private let bigCover: CGFloat = 132

    var body: some View {
        let island = state.islandSize
        let collapsed = state.collapsedSize
        let w = state.isExpanded ? island.width : collapsed.width
        let h = state.isExpanded ? island.height : collapsed.height
        let stripRadius: CGFloat = 10
        let bottomRadius: CGFloat = state.isExpanded ? 28 : (state.musicMode ? stripRadius : 28)

        ZStack(alignment: .top) {
            NotchShape(bottomCornerRadius: bottomRadius)
                .fill(Color.black)
                .frame(width: w, height: h)
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: state.isExpanded)
                .animation(.spring(response: 0.34, dampingFraction: 0.9), value: state.collapsedSize)
                .animation(.easeInOut(duration: 0.32), value: state.islandSize)

            // The 2-page pager (only when expanded).
            if state.isExpanded {
                pager(island)
                    .frame(width: island.width, height: island.height, alignment: .top)
                    .clipShape(NotchShape(bottomCornerRadius: bottomRadius))
                pageDots
            }

            // Header strip (pulse) stays at the top on both pages.
            if state.musicMode {
                MusicStripView(monitor: monitor, notchWidth: notchSize.width, height: collapsed.height)
                    .frame(width: collapsed.width, height: collapsed.height, alignment: .top)
                    .clipShape(NotchShape(bottomCornerRadius: stripRadius))
            }

            // Album cover: a single overlay that grows and travels between the strip
            // spot and the music-page spot, tracking the swipe progress.
            if state.musicMode {
                let p = coverProgress()
                let size = lerp(smallCoverSize, bigCover, p)
                coverImage
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: lerp(5, 16, p), style: .continuous))
                    .position(x: lerp(smallCoverCenter.x, bigCoverCenter.x, p),
                              y: lerp(smallCoverCenter.y, bigCoverCenter.y, p))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: max(island.width, collapsed.width), height: island.height, alignment: .top)
        .animation(.easeInOut(duration: 0.32), value: state.islandSize)
    }

    // MARK: - Hero cover geometry

    /// 0 = metrics/collapsed (small, in the strip), 1 = music page (big). Tracks the
    /// live drag so the cover follows the swipe.
    private func coverProgress() -> CGFloat {
        let base = CGFloat(state.currentPage)
        let dragProgress = -drag / max(state.islandSize.width, 1)
        return min(max(base + dragProgress, 0), 1)
    }
    private var smallCoverSize: CGFloat { max(state.collapsedSize.height - 10, 16) }
    private var smallCoverCenter: CGPoint {
        CGPoint(x: state.islandSize.width / 2 - state.collapsedSize.width / 2 + MusicStripView.sideExtension / 2,
                y: state.collapsedSize.height / 2)
    }
    private var bigCoverCenter: CGPoint {
        CGPoint(x: 24 + bigCover / 2, y: state.islandSize.height / 2)
    }
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    private func pager(_ island: CGSize) -> some View {
        // Both pages share the island height, so swiping never resizes anything.
        HStack(alignment: .top, spacing: 0) {
            ExpandedView(sampler: sampler, topInset: topInset)
                .frame(width: island.width, height: island.height, alignment: .top)
            MusicControlView(monitor: monitor, coverSize: bigCover, topInset: topInset)
                .frame(width: island.width, height: island.height, alignment: .top)
        }
        .frame(width: island.width, alignment: .leading)
        .offset(x: -CGFloat(state.currentPage) * island.width + drag)
        .frame(width: island.width, height: island.height, alignment: .top)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { g in drag = g.translation.width }
                .onEnded { g in endDrag(g.translation.width, island.width) }
        )
    }

    @ViewBuilder private var coverImage: some View {
        if let art = monitor.artwork {
            Image(nsImage: art).resizable().scaledToFill()
        } else {
            ZStack { Color.white.opacity(0.12); Image(systemName: "music.note").foregroundStyle(.white.opacity(0.7)) }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(state.currentPage == i ? 0.85 : 0.25))
                    .frame(width: 5, height: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 7)
    }

    private func endDrag(_ translation: CGFloat, _ width: CGFloat) {
        let threshold = width * 0.22
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            if translation < -threshold { state.currentPage = min(state.currentPage + 1, 1) }
            else if translation > threshold { state.currentPage = max(state.currentPage - 1, 0) }
            drag = 0
        }
    }
}
