import AppKit
import SwiftUI

/// A borderless, non-activating panel that is **hidden by default** and drops down
/// from under the notch when the cursor hovers the notch region.
///
/// Hover is detected by polling the cursor position (`NSEvent.mouseLocation`) on a
/// timer — it reads only where the cursor is (never clicks or keystrokes), needs no
/// permissions, and works while the panel is hidden.
final class NotchPanel: NSPanel {

    private let sampler: MetricsSampler
    private let state = PanelState()
    private var expandedSize = NSSize(width: 300, height: 150)
    private var hoverTimer: Timer?
    private var isExpanded = false

    init(sampler: MetricsSampler) {
        self.sampler = sampler
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 150),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Float above the menu bar, never steal focus, stay put across Spaces.
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        // No window shadow: it haloed the top edge gray. The island reads as a
        // solid black extension of the notch instead.
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        // Menu-bar/notch height to clear at the top so content sits in the visible area.
        let topInset: CGFloat = NotchPanel.notchScreen()
            .map { max($0.safeAreaInsets.top, $0.frame.maxY - $0.visibleFrame.maxY) } ?? 32

        // Measure the content once so frames are exact.
        let measure = NSHostingView(rootView: ExpandedView(sampler: sampler, topInset: topInset))
        measure.layoutSubtreeIfNeeded()
        let fitting = measure.fittingSize
        if fitting.width > 1, fitting.height > 1 { expandedSize = fitting }

        // The notch's footprint, used as the morph's start size.
        let notchSize: CGSize = NotchPanel.notchScreen().map {
            CGSize(width: max(NotchPanel.notchRect(on: $0).width, 120),
                   height: max($0.safeAreaInsets.top, $0.frame.maxY - $0.visibleFrame.maxY))
        } ?? CGSize(width: 180, height: 32)

        // The window stays at the fixed island size; the morph happens entirely in
        // SwiftUI (the shape grows from the notch size, metrics fade in) so the
        // window frame never animates — no sliding/glitching.
        let hosting = NSHostingView(rootView: NotchContentView(
            sampler: sampler, state: state, topInset: topInset,
            notchSize: notchSize, islandSize: expandedSize
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

        // Dev quit affordance: right-click the revealed panel to Quit.
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit SystemPeek",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        hosting.menu = menu
        contentView = container

        // Fixed island-sized window, anchored to the top; starts hidden.
        setFrame(expandedFrame(), display: false)
        startHoverTracking()
    }

    // Display-only panel: never becomes key or main.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Re-anchor while revealed (e.g. after a display change).
    func reposition() {
        if isExpanded { setFrame(expandedFrame(), display: true) }
    }

    // MARK: - Hover (cursor-position polling)

    private func startHoverTracking() {
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateHover() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    /// Reveal while the cursor is over the notch region (or the revealed panel),
    /// hide otherwise. The revealed panel keeps it open so the cursor can move
    /// from the notch down into the metrics.
    private func updateHover() {
        guard let screen = NotchPanel.notchScreen() else { return }
        let mouse = NSEvent.mouseLocation
        if isExpanded {
            // Stay open anywhere from the panel up to the very top of the screen,
            // across the panel's full width — so moving up to/under the notch (even
            // off-centre) keeps it revealed.
            if !keepOpenZone(on: screen).contains(mouse) { collapse() }
        } else if notchHoverZone(on: screen).contains(mouse) {
            expand()
        }
    }

    private func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        // Window is already island-sized and anchored at the notch; just show it
        // and let SwiftUI morph the shape out from the notch.
        alphaValue = 1
        setFrame(expandedFrame(), display: false)
        orderFrontRegardless()
        state.isExpanded = true
    }

    private func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        state.isExpanded = false   // SwiftUI morphs the shape back into the notch
        // Fade the window out as it retracts so the shape's final edge never sits
        // as a visible line/bump under the notch before hiding.
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.isExpanded else { return }
            self.orderOut(nil)
            self.alphaValue = 1   // reset for the next reveal
        })
    }

    // MARK: - Frames

    private func topInset(on screen: NSScreen) -> CGFloat {
        max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY)
    }

    /// A few pixels of headroom above the screen's top edge. NSRect.contains treats
    /// the top edge as exclusive, so without this the very top menu-bar row (the
    /// highest the cursor can reach) wouldn't count as "inside" the zone.
    private let topOverscan: CGFloat = 8

    /// The trigger region: the notch (plus a small side margin and below) so that
    /// moving the cursor up to the notch — including sliding along the very top of
    /// the screen across it — reveals the panel.
    private func notchHoverZone(on screen: NSScreen) -> NSRect {
        let notch = NotchPanel.notchRect(on: screen)
        let inset = topInset(on: screen)
        let width = max(notch.width, 120) + 40   // ~20pt margin each side of the notch
        let bottom = screen.frame.maxY - inset - 8
        return NSRect(
            x: notch.midX - width / 2,
            y: bottom,
            width: width,
            height: screen.frame.maxY + topOverscan - bottom
        )
    }

    /// The keep-open region while revealed: a full-panel-width column from the
    /// bottom of the panel all the way up past the top of the screen. This spans the
    /// panel, the gap, the notch, and the menu-bar area beside it, so the cursor
    /// can move freely between the notch and the metrics without it collapsing.
    private func keepOpenZone(on screen: NSScreen) -> NSRect {
        let notch = NotchPanel.notchRect(on: screen)
        let panel = expandedFrame()
        let width = max(panel.width, notch.width)
        return NSRect(
            x: notch.midX - width / 2,
            y: panel.minY,
            width: width,
            height: screen.frame.maxY + topOverscan - panel.minY
        )
    }

    /// Revealed frame: anchored to the very top of the screen so the notch column
    /// overlays the menu bar and merges with the real notch.
    private func expandedFrame() -> NSRect {
        guard let screen = NotchPanel.notchScreen() else { return frame }
        let notch = NotchPanel.notchRect(on: screen)
        return NSRect(
            x: notch.midX - expandedSize.width / 2,
            y: screen.frame.maxY - expandedSize.height,
            width: expandedSize.width,
            height: expandedSize.height
        )
    }

    deinit {
        hoverTimer?.invalidate()
    }

    // MARK: - Notch geometry

    /// The screen that has a notch, falling back to the main screen.
    static func notchScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    /// Rect (in global screen coordinates) covering the notch.
    ///
    /// `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` are the menu-bar regions
    /// either side of the camera housing; the notch sits between them. When there
    /// is no notch, returns a zero-height rect centered at the top of the screen.
    static func notchRect(on screen: NSScreen) -> NSRect {
        let topInset = screen.safeAreaInsets.top
        if topInset > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let minX = left.maxX
            let maxX = right.minX
            return NSRect(
                x: minX,
                y: screen.frame.maxY - topInset,
                width: max(maxX - minX, 0),
                height: topInset
            )
        }
        return NSRect(
            x: screen.frame.midX - minimumWidthFallback / 2,
            y: screen.frame.maxY,
            width: minimumWidthFallback,
            height: 0
        )
    }

    private static let minimumWidthFallback: CGFloat = 180
}

/// Shared reveal state so the SwiftUI metrics can fade in/out in step with the
/// window's morph animation.
@MainActor
final class PanelState: ObservableObject {
    @Published var isExpanded = false
}

/// The panel's content, in a fixed island-sized container. The black NotchShape
/// animates its size from the notch footprint up to the island while the metrics
/// fade in — the whole morph happens in SwiftUI, so the window never resizes.
private struct NotchContentView: View {
    @ObservedObject var sampler: MetricsSampler
    @ObservedObject var state: PanelState
    var topInset: CGFloat
    var notchSize: CGSize
    var islandSize: CGSize

    var body: some View {
        let w = state.isExpanded ? islandSize.width : notchSize.width
        let h = state.isExpanded ? islandSize.height : notchSize.height
        ZStack(alignment: .top) {
            NotchShape()
                .fill(Color.black)
                .frame(width: w, height: h)
                .animation(.spring(response: 0.34, dampingFraction: 0.86), value: state.isExpanded)

            // Metrics are clipped to the (morphing) notch outline so they can never
            // show outside it, and they hide fast — so when the notch retracts the
            // items are gone immediately, not lingering for a split second.
            ExpandedView(sampler: sampler, topInset: topInset)
                .frame(width: w, height: h, alignment: .top)
                .clipShape(NotchShape())
                .opacity(state.isExpanded ? 1 : 0)
                .animation(.easeOut(duration: 0.08), value: state.isExpanded)
        }
        .frame(width: islandSize.width, height: islandSize.height, alignment: .top)
    }
}
