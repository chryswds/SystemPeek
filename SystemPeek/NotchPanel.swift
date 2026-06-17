import AppKit
import SwiftUI

/// A borderless, non-activating panel pinned under the screen's notch.
///
/// This commit hosts the live telemetry panel (`ExpandedView`) and sizes itself
/// to that content. Hover-driven collapse/expand arrives in the next commit;
/// for now the panel always shows the expanded contents.
final class NotchPanel: NSPanel {

    private let sampler: MetricsSampler

    init(sampler: MetricsSampler) {
        self.sampler = sampler
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 290, height: 150),
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

        let host = NSHostingView(rootView: ExpandedView(sampler: sampler))
        host.layer?.backgroundColor = .clear
        contentView = host
        host.layoutSubtreeIfNeeded()

        reposition()
    }

    // Display-only panel: never becomes key or main.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Size to fit the hosted SwiftUI content and anchor centered under the notch.
    func reposition() {
        guard let screen = NotchPanel.notchScreen() else { return }
        let notch = NotchPanel.notchRect(on: screen)

        var size = contentView?.fittingSize ?? .zero
        if size.width < 1 || size.height < 1 {
            size = NSSize(width: 290, height: 150)
        }

        let origin = NSPoint(
            x: notch.midX - size.width / 2,
            y: screen.frame.maxY - size.height
        )
        setFrame(NSRect(origin: origin, size: size), display: true)
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
        // No notch: synthesize a top-center anchor.
        return NSRect(
            x: screen.frame.midX - minimumWidthFallback / 2,
            y: screen.frame.maxY,
            width: minimumWidthFallback,
            height: 0
        )
    }

    private static let minimumWidthFallback: CGFloat = 180
}
