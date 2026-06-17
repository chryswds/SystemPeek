import XCTest
import AppKit
import CoreGraphics

/// End-to-end test of the notch widget: launch the real app, move the system
/// cursor onto the panel, and assert it expands; move the cursor away and assert
/// it collapses — observed via the live window height from the window list.
///
/// This deliberately does **not** use `XCUIApplication`: XCUITest's automation
/// session parks/controls the cursor (overriding CGWarp) and mis-maps hover
/// coordinates for an overlay panel on a secondary display. Launching the app
/// directly leaves the cursor fully under our control.
///
/// Note: the test moves the cursor, so don't drive the mouse while it runs.
final class HoverExpandUITests: XCTestCase {
    private let bundleID = "com.chrys.SystemPeek"
    private let collapsedMax: CGFloat = 60   // collapsed strip is ~32pt tall
    private let expandedMin: CGFloat = 80    // expanded panel is ~120pt+ tall

    override func setUp() {
        continueAfterFailure = false
        terminateSystemPeek()
    }

    override func tearDown() {
        terminateSystemPeek()
    }

    func testLaunchHoverExpandCollapse() throws {
        try launchSystemPeek()

        // The panel appears collapsed shortly after launch.
        guard let collapsed = waitForWindow(timeout: 20) else {
            return XCTFail("SystemPeek panel window did not appear")
        }
        XCTAssertLessThan(collapsed.rect.height, collapsedMax, "Panel should start collapsed")

        // Hover: move the cursor onto the panel -> it expands.
        let center = CGPoint(x: collapsed.rect.midX, y: collapsed.rect.midY)
        CGWarpMouseCursorPosition(center)
        XCTAssertTrue(
            waitForHeight({ $0 > self.expandedMin }, timeout: 5),
            "Panel should expand when the cursor is over it"
        )

        // Move the cursor well below the panel -> it collapses again.
        CGWarpMouseCursorPosition(CGPoint(x: center.x, y: center.y + 400))
        XCTAssertTrue(
            waitForHeight({ $0 < self.collapsedMax }, timeout: 5),
            "Panel should collapse when the cursor leaves"
        )
    }

    // MARK: - Launching / terminating the real app

    /// Locate the built SystemPeek.app next to the test bundle in the products dir.
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

    // MARK: - Window polling (CoreGraphics — no special permissions)

    private struct Win { let rect: CGRect }

    private func systemPeekWindow() -> Win? {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for window in list where (window[kCGWindowOwnerName as String] as? String) == "SystemPeek" {
            if let bounds = window[kCGWindowBounds as String] as? [String: Any],
               let x = bounds["X"] as? CGFloat, let y = bounds["Y"] as? CGFloat,
               let width = bounds["Width"] as? CGFloat, let height = bounds["Height"] as? CGFloat,
               height > 0 {
                return Win(rect: CGRect(x: x, y: y, width: width, height: height))
            }
        }
        return nil
    }

    private func waitForWindow(timeout: TimeInterval) -> Win? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let window = systemPeekWindow() { return window }
            usleep(150_000)
        }
        return nil
    }

    private func waitForHeight(_ predicate: (CGFloat) -> Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let window = systemPeekWindow(), predicate(window.rect.height) { return true }
            usleep(100_000)
        }
        return false
    }
}
