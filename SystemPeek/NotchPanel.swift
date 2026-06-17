import AppKit
import SwiftUI
import Combine

/// Observable collapse/expand state shared between the panel and its SwiftUI
/// content so the two stay in sync.
@MainActor
final class PanelState: ObservableObject {
    @Published var isExpanded = false
}

/// A borderless, non-activating panel pinned just under the screen's notch. Shows
/// a slim strip by default and expands to the live telemetry panel on hover,
/// animating its window frame between the two.
///
/// Hover is detected by polling the cursor position (`NSEvent.mouseLocation`) on a
/// timer rather than an NSTrackingArea: tracking-area enter/exit is unreliable for
/// a non-activating overlay panel and churns when the window resizes. Polling the
/// pointer location needs no permissions and is **not** input monitoring — it
/// reads only where the cursor is, never clicks or keystrokes.
final class NotchPanel: NSPanel {

    private let sampler: MetricsSampler
    private let state = PanelState()
    private let collapsedHeight: CGFloat = 32
    private let minimumCollapsedWidth: CGFloat = 150
    private var expandedSize = NSSize(width: 290, height: 140)
    private var hoverTimer: Timer?

    init(sampler: MetricsSampler) {
        self.sampler = sampler
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 140),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Float above the menu bar, never steal focus, stay put across Spaces.
        isFloatingPanel = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        // Measure the expanded content once so frame math is exact.
        let measure = NSHostingView(rootView: ExpandedView(sampler: sampler))
        measure.layoutSubtreeIfNeeded()
        let fitting = measure.fittingSize
        if fitting.width > 1, fitting.height > 1 { expandedSize = fitting }

        let hosting = NSHostingView(rootView: NotchContentView(sampler: sampler, state: state))

        // Dev quit affordance: as an .accessory app there's no Dock/menu, so a
        // right-click on the panel offers Quit.
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Quit SystemPeek",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        hosting.menu = menu
        contentView = hosting

        setFrame(collapsedFrame(), display: true)
        startHoverTracking()
    }

    // Display-only panel: never becomes key or main.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Re-anchor for the current state (e.g. after a display change).
    func reposition() {
        setFrame(state.isExpanded ? expandedFrame() : collapsedFrame(), display: true)
    }

    // MARK: - Hover (cursor-position polling)

    private func startHoverTracking() {
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateHover() }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
    }

    /// Expand while the cursor is within the active zone, collapse otherwise.
    /// The zone is the (larger) expanded frame while open, giving hysteresis.
    private func updateHover() {
        let zone = state.isExpanded ? expandedFrame() : collapsedFrame()
        if zone.contains(NSEvent.mouseLocation) {
            expand()
        } else {
            collapse()
        }
    }

    private func expand() {
        guard !state.isExpanded else { return }
        state.isExpanded = true
        animateFrame(to: expandedFrame())
    }

    private func collapse() {
        guard state.isExpanded else { return }
        state.isExpanded = false
        animateFrame(to: collapsedFrame())
    }

    private func animateFrame(to target: NSRect) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(target, display: true)
        }
    }

    // MARK: - Frames

    /// Y of the panel's top edge: just below the notch (or the menu bar on
    /// notch-less Macs), so the panel lives in real screen pixels — not over the
    /// physical notch cutout, where the cursor can't actually hover.
    private func topAnchorY(on screen: NSScreen) -> CGFloat {
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        let inset = screen.safeAreaInsets.top
        return screen.frame.maxY - max(inset, menuBar)
    }

    private func collapsedFrame() -> NSRect {
        guard let screen = NotchPanel.notchScreen() else { return frame }
        let notch = NotchPanel.notchRect(on: screen)
        let width = max(notch.width, minimumCollapsedWidth)
        let top = topAnchorY(on: screen)
        return NSRect(
            x: notch.midX - width / 2,
            y: top - collapsedHeight,
            width: width,
            height: collapsedHeight
        )
    }

    private func expandedFrame() -> NSRect {
        guard let screen = NotchPanel.notchScreen() else { return frame }
        let notch = NotchPanel.notchRect(on: screen)
        let top = topAnchorY(on: screen)
        return NSRect(
            x: notch.midX - expandedSize.width / 2,
            y: top - expandedSize.height,
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

/// Switches between the collapsed strip and the expanded telemetry panel,
/// cross-fading on state change. The window animates its size in parallel.
private struct NotchContentView: View {
    @ObservedObject var sampler: MetricsSampler
    @ObservedObject var state: PanelState

    var body: some View {
        ZStack {
            if state.isExpanded {
                ExpandedView(sampler: sampler)
                    .transition(.opacity)
            } else {
                CollapsedView(sampler: sampler)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: state.isExpanded)
    }
}
