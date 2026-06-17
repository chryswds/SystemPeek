import AppKit

/// Owns the app lifecycle. Runs as an `.accessory` app (no Dock icon, no menu
/// bar presence) and will own the notch panel + metrics sampler as those land
/// in later commits.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Background/agent app: no Dock tile, doesn't steal focus.
        NSApp.setActivationPolicy(.accessory)
    }
}
