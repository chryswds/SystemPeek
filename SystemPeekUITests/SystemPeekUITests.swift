import XCTest

/// Placeholder so the UI-test target builds from the first commit.
/// Real end-to-end hover tests arrive with the hover feature.
final class SystemPeekUITests: XCTestCase {
    func testAppLaunches() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10) ||
                      app.state == .runningBackground)
        app.terminate()
    }
}
