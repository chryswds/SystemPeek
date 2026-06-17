import XCTest
@testable import SystemPeek

final class CPUUsageTests: XCTestCase {
    private func ticks(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32 = 0) -> CPUTicks {
        CPUTicks(user: user, system: system, idle: idle, nice: nice)
    }

    func testFullyBusy() {
        let prev = ticks(user: 0, system: 0, idle: 0)
        let curr = ticks(user: 70, system: 30, idle: 0)
        XCTAssertEqual(CPUUsage.busyPercent(previous: prev, current: curr), 100, accuracy: 0.0001)
    }

    func testFullyIdle() {
        let prev = ticks(user: 0, system: 0, idle: 0)
        let curr = ticks(user: 0, system: 0, idle: 100)
        XCTAssertEqual(CPUUsage.busyPercent(previous: prev, current: curr), 0, accuracy: 0.0001)
    }

    func testHalfBusy() {
        let prev = ticks(user: 10, system: 10, idle: 10)
        let curr = ticks(user: 35, system: 35, idle: 60) // +50 busy, +50 idle
        XCTAssertEqual(CPUUsage.busyPercent(previous: prev, current: curr), 50, accuracy: 0.0001)
    }

    func testNiceCountsAsBusy() {
        let prev = ticks(user: 0, system: 0, idle: 0, nice: 0)
        let curr = ticks(user: 0, system: 0, idle: 50, nice: 50)
        XCTAssertEqual(CPUUsage.busyPercent(previous: prev, current: curr), 50, accuracy: 0.0001)
    }

    func testNoElapsedTimeReturnsZero() {
        let same = ticks(user: 5, system: 5, idle: 5)
        XCTAssertEqual(CPUUsage.busyPercent(previous: same, current: same), 0)
    }

    func testCounterWraparoundReturnsZero() {
        let prev = ticks(user: 100, system: 100, idle: 100)
        let curr = ticks(user: 0, system: 0, idle: 0) // counters went backwards
        XCTAssertEqual(CPUUsage.busyPercent(previous: prev, current: curr), 0)
    }

    func testResultIsClampedTo100() {
        let prev = ticks(user: 0, system: 0, idle: 10)
        let curr = ticks(user: 100, system: 0, idle: 5) // busy grew, idle shrank
        let pct = CPUUsage.busyPercent(previous: prev, current: curr)
        XCTAssertLessThanOrEqual(pct, 100)
        XCTAssertGreaterThanOrEqual(pct, 0)
    }
}
