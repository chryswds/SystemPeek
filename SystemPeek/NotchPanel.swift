import AppKit

/// A borderless, non-activating panel pinned under the screen's notch.
///
/// This commit establishes positioning only: it shows a simple placeholder strip
/// hugging the notch to prove the geometry is right. Hover-to-expand, live
/// metrics, and final styling arrive in later commits.
final class NotchPanel: NSPanel {

    /// Height of the collapsed strip. Its width is derived from the notch.
    private let collapsedHeight: CGFloat = 32
    /// Minimum width when the notch is narrow or absent.
    private let minimumWidth: CGFloat = 180

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 32),
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

        // Placeholder visual: a black strip with rounded bottom corners that
        // visually extends the notch downward.
        let content = NSView()
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.black.cgColor
        content.layer?.cornerRadius = 10
        content.layer?.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        contentView = content

        reposition()
    }

    // Display-only panel: never becomes key or main.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Position the strip centered under the notch (or top-center if no notch).
    func reposition() {
        guard let screen = NotchPanel.notchScreen() else { return }
        let notch = NotchPanel.notchRect(on: screen)
        let width = max(notch.width, minimumWidth)
        let size = NSSize(width: width, height: collapsedHeight)
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
