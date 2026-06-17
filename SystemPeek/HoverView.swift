import AppKit

/// A content view that reports mouse enter/exit using a **local** tracking area
/// (never a global event monitor), so SystemPeek can detect hover over the notch
/// without any system-wide input monitoring.
final class HoverView: NSView {
    var onEnter: () -> Void = {}
    var onExit: () -> Void = {}

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        // .inVisibleRect keeps the tracking area matched to the view as the
        // panel resizes between its collapsed and expanded frames.
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) { onEnter() }
    override func mouseExited(with event: NSEvent) { onExit() }
}
