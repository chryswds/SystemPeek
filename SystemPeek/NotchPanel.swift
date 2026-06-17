import AppKit
import SwiftUI
import Combine

/// Observable collapse/expand state shared between the panel and its SwiftUI
/// content so the two stay in sync.
@MainActor
final class PanelState: ObservableObject {
    @Published var isExpanded = false
}

/// A borderless, non-activating panel pinned under the screen's notch. Shows a
/// slim strip by default and expands to the live telemetry panel on hover,
/// animating its window frame between the two.
final class NotchPanel: NSPanel {

    private let sampler: MetricsSampler
    private let state = PanelState()
    private let collapsedHeight: CGFloat = 32
    private let minimumCollapsedWidth: CGFloat = 150
    private var expandedSize: NSSize = NSSize(width: 290, height: 140)

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
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        // Measure the expanded content once so frame math is exact.
        let measure = NSHostingView(rootView: ExpandedView(sampler: sampler))
        measure.layoutSubtreeIfNeeded()
        let fitting = measure.fittingSize
        if fitting.width > 1, fitting.height > 1 { expandedSize = fitting }

        // Content: a hover-tracking view hosting the collapsed/expanded SwiftUI.
        let hosting = NSHostingView(rootView: NotchContentView(sampler: sampler, state: state))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let hover = HoverView()
        hover.onEnter = { [weak self] in self?.expand() }
        hover.onExit = { [weak self] in self?.collapse() }
        hover.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: hover.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: hover.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: hover.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: hover.bottomAnchor),
        ])
        contentView = hover

        setFrame(collapsedFrame(), display: true)
    }

    // Display-only panel: never becomes key or main.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Re-anchor for the current state (e.g. after a display change).
    func reposition() {
        setFrame(state.isExpanded ? expandedFrame() : collapsedFrame(), display: true)
    }

    // MARK: - Expand / collapse

    private func expand() {
        guard !state.isExpanded else { return }
        state.isExpanded = true
        animateFrame(to: expandedFrame())
    }

    private func collapse() {
        guard state.isExpanded else { return }
        // Keep the expanded content during the shrink, then swap to the strip.
        animateFrame(to: collapsedFrame()) { [weak self] in
            self?.state.isExpanded = false
        }
    }

    private func animateFrame(to target: NSRect, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().setFrame(target, display: true)
        }, completionHandler: completion)
    }

    // MARK: - Frames

    private func collapsedFrame() -> NSRect {
        guard let screen = NotchPanel.notchScreen() else { return frame }
        let notch = NotchPanel.notchRect(on: screen)
        let width = max(notch.width, minimumCollapsedWidth)
        return NSRect(
            x: notch.midX - width / 2,
            y: screen.frame.maxY - collapsedHeight,
            width: width,
            height: collapsedHeight
        )
    }

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
                CollapsedStrip()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: state.isExpanded)
    }
}

/// Minimal collapsed look: a black strip that visually extends the notch.
/// (Refined into a dedicated CollapsedView in the next commit.)
private struct CollapsedStrip: View {
    var body: some View {
        UnevenRoundedRectangle(
            bottomLeadingRadius: 10,
            bottomTrailingRadius: 10,
            style: .continuous
        )
        .fill(Color.black)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("collapsedStrip")
    }
}
