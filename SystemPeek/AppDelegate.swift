import AppKit

/// Owns the app lifecycle. Runs as an `.accessory` app (no Dock icon, no menu
/// bar presence) and owns the notch panel.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchPanel: NotchPanel?
    private let sampler = MetricsSampler()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background/agent app: no Dock tile, doesn't steal focus.
        NSApp.setActivationPolicy(.accessory)

        sampler.start()

        // The panel manages its own visibility: hidden until the notch is hovered.
        let panel = NotchPanel(sampler: sampler)
        notchPanel = panel

        // Keep the panel anchored when displays change (resolution, plugging in
        // an external monitor, etc.).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screenParametersChanged() {
        notchPanel?.reposition()
    }
}
