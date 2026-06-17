import XCTest
import AppKit
import CoreGraphics

/// End-to-end test of the notch widget: launch the real app, confirm nothing is
/// shown by default, move the cursor onto the notch region to reveal the panel,
/// then move away to confirm it hides again — observed via the live window list.
///
/// This deliberately does **not** use `XCUIApplication`: XCUITest's automation
/// session parks/controls the cursor (overriding CGWarp) and mis-maps hover
/// coordinates for an overlay panel on a secondary display. Launching the app
/// directly leaves the cursor fully under our control.
///
/// Note: the test moves the cursor, so don't drive the mouse while it runs.
final class HoverExpandUITests: XCTestCase {
    private let bundleID = "com.chrys.SystemPeek"
    private let revealedMin: CGFloat = 80   // revealed panel is ~120pt+ tall

    override func setUp() {
        continueAfterFailure = false
        terminateSystemPeek()
    }

    override func tearDown() {
        terminateSystemPeek()
    }

    func testNotchHoverRevealsThenHides() throws {
        try launchSystemPeek()
        Thread.sleep(forTimeInterval: 1.5)

        // Nothing is shown until the notch is hovered.
        XCTAssertNil(systemPeekWindow(), "Panel should be hidden until the notch is hovered")

        let hover = try XCTUnwrap(notchHoverPoint(), "No notch display found")

        // Hover the notch -> the panel drops down.
        CGWarpMouseCursorPosition(hover)
        XCTAssertTrue(
            waitForWindow(where: { $0.height > revealedMin }, timeout: 6),
            "Hovering the notch should reveal the panel"
        )

        // Move the cursor away -> the panel hides again.
        CGWarpMouseCursorPosition(awayPoint())
        XCTAssertTrue(
            waitForNoWindow(timeout: 6),
            "Panel should hide when the cursor leaves the notch"
        )
    }

    // MARK: - Launching / terminating the real app

    private func appURL() -> URL? {
        var dir = Bundle(for: type(of: self)).bundleURL
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent("SystemPeek.app")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    private func launchSystemPeek() throws {
        let url = try XCTUnwrap(appURL(), "Could not locate built SystemPeek.app")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [url.path]
        try process.run()
        process.waitUntilExit()
    }

    private func terminateSystemPeek() {
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
            app.terminate()
        }
    }

    // MARK: - Target points (in CoreGraphics top-left global coordinates)

    /// Center-top of the notch, where hovering should reveal the panel.
    private func notchHoverPoint() -> CGPoint? {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }),
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea else { return nil }
        let centerX = (left.maxX + right.minX) / 2
        let cocoaY = screen.frame.maxY - 3   // just under the notch, inside the trigger zone
        return CGPoint(x: centerX, y: flipToCG(cocoaY))
    }

    /// A point far from the notch/panel on the same display.
    private func awayPoint() -> CGPoint {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main!
        return CGPoint(x: screen.frame.midX, y: flipToCG(screen.frame.midY))
    }

    /// Cocoa global Y (bottom-left) -> CoreGraphics global Y (top-left).
    private func flipToCG(_ cocoaY: CGFloat) -> CGFloat {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main!
        return primary.frame.height - cocoaY
    }

    // MARK: - Window polling (CoreGraphics — no special permissions)

    private struct Win { let rect: CGRect }

    private func systemPeekWindow() -> Win? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for window in list where (window[kCGWindowOwnerName as String] as? String) == "SystemPeek" {
            // Only the floating notch panel (high window layer); ignore the normal
            // settings window (layer 0).
            guard (window[kCGWindowLayer as String] as? Int ?? 0) > 0 else { continue }
            if let bounds = window[kCGWindowBounds as String] as? [String: Any],
               let x = bounds["X"] as? CGFloat, let y = bounds["Y"] as? CGFloat,
               let width = bounds["Width"] as? CGFloat, let height = bounds["Height"] as? CGFloat,
               height > 2 {
                return Win(rect: CGRect(x: x, y: y, width: width, height: height))
            }
        }
        return nil
    }

    private func waitForWindow(where predicate: (CGRect) -> Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let window = systemPeekWindow(), predicate(window.rect) { return true }
            usleep(100_000)
        }
        return false
    }

    private func waitForNoWindow(timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if systemPeekWindow() == nil { return true }
            usleep(100_000)
        }
        return systemPeekWindow() == nil
    }
}
