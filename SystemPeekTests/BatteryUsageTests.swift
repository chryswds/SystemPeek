import XCTest
@testable import SystemPeek

final class BatteryUsageTests: XCTestCase {
    func testPercentIsCurrentOverMax() {
        XCTAssertEqual(BatteryUsage.percent(current: 74, max: 100), 74, accuracy: 0.001)
        XCTAssertEqual(BatteryUsage.percent(current: 1, max: 2), 50, accuracy: 0.001)
    }

    func testPercentClampsToHundred() {
        XCTAssertEqual(BatteryUsage.percent(current: 120, max: 100), 100)
    }

    func testZeroMaxYieldsZero() {
        XCTAssertEqual(BatteryUsage.percent(current: 50, max: 0), 0)
    }
}
