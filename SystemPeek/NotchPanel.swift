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
        hasShadow = true
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]

        // Measure the content once so frames are exact.
        let measure = NSHostingView(rootView: ExpandedView(sampler: sampler))
        measure.layoutSubtreeIfNeeded()
        let fitting = measure.fittingSize
        if fitting.width > 1, fitting.height > 1 { expandedSize = fitting }

        // Pin the content to the top at its full size so that, as the window grows
        // from a sliver to full height, the panel is revealed top-to-bottom.
        let hosting = NSHostingView(rootView: ExpandedView(sampler: sampler))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: container.topAnchor),
            hosting.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            hosting.widthAnchor.constraint(equalToConstant: expandedSize.width),
            hosting.heightAnchor.constraint(equalToConstant: expandedSize.height),
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

        // Start hidden; the hover poll reveals it.
        setFrame(startFrame(), display: false)
        alphaValue = 0
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
        setFrame(startFrame(), display: false)
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
            animator().setFrame(expandedFrame(), display: true)
        }
    }

    private func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
            animator().setFrame(startFrame(), display: true)
        }, completionHandler: { [weak self] in
            guard let self, !self.isExpanded else { return }
            self.orderOut(nil)
        })
    }

    // MARK: - Frames

    /// Y of the panel's top edge: just below the notch (or the menu bar on
    /// notch-less Macs).
    private func topAnchorY(on screen: NSScreen) -> CGFloat {
        screen.frame.maxY - topInset(on: screen)
    }

    private func topInset(on screen: NSScreen) -> CGFloat {
        max(screen.safeAreaInsets.top, screen.frame.maxY - screen.visibleFrame.maxY)
    }

    /// The trigger region: the notch itself plus a few pixels below, so moving the
    /// cursor up to the notch reveals the panel.
    private func notchHoverZone(on screen: NSScreen) -> NSRect {
        let notch = NotchPanel.notchRect(on: screen)
        let inset = topInset(on: screen)
        let width = max(notch.width, 120)
        return NSRect(
            x: notch.midX - width / 2,
            y: screen.frame.maxY - inset - 6,
            width: width,
            height: inset + 6
        )
    }

    /// The keep-open region while revealed: a full-panel-width column from the
    /// bottom of the panel all the way up to the top of the screen. This spans the
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
            height: screen.frame.maxY - panel.minY
        )
    }

    /// Hidden start/end frame: a 1pt sliver under the notch that the reveal grows
    /// downward from.
    private func startFrame() -> NSRect {
        guard let screen = NotchPanel.notchScreen() else { return frame }
        let notch = NotchPanel.notchRect(on: screen)
        let top = topAnchorY(on: screen)
        return NSRect(x: notch.midX - expandedSize.width / 2, y: top - 1, width: expandedSize.width, height: 1)
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
