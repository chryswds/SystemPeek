import AppKit
import SwiftUI

/// Owns the app lifecycle. Runs as an `.accessory` app (no Dock icon, no menu
/// bar presence) and owns the notch panel and the settings window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchPanel: NotchPanel?
    private let sampler = MetricsSampler()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background/agent app: no Dock tile, doesn't steal focus.
        NSApp.setActivationPolicy(.accessory)

        // When this app is the unit-test host, don't spin up the live UI (panel,
        // settings window) — those tests drive the metrics logic directly.
        guard NSClassFromString("XCTestCase") == nil else { return }

        sampler.start()

        // The panel manages its own visibility: hidden until the notch is hovered.
        let panel = NotchPanel(sampler: sampler, onOpenSettings: { [weak self] in
            self?.showSettings()
        })
        notchPanel = panel

        // Keep the panel anchored when displays change (resolution, plugging in
        // an external monitor, etc.).
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Show settings the first time the app is ever launched so it's discoverable.
        if !UserDefaults.standard.bool(forKey: "didLaunchBefore") {
            UserDefaults.standard.set(true, forKey: "didLaunchBefore")
            DispatchQueue.main.async { [weak self] in self?.showSettings() }
        }
    }

    /// Re-opening the app (e.g. from Spotlight/Finder while it's already running)
    /// brings up settings, since there's no Dock icon or window otherwise.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    @objc private func screenParametersChanged() {
        notchPanel?.reposition()
    }

    private func showSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: controller)
            window.title = "SystemPeek"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
