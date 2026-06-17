import XCTest
@testable import SystemPeek

final class NetworkUsageTests: XCTestCase {
    func testThroughputIsBytesPerSecond() {
        let previous = NetworkSample(receivedBytes: 1000, sentBytes: 500)
        let current = NetworkSample(receivedBytes: 3000, sentBytes: 1500)
        let rates = NetworkUsage.throughput(previous: previous, current: current, interval: 2)
        XCTAssertEqual(rates.down, 1000, accuracy: 0.001) // (3000-1000)/2
        XCTAssertEqual(rates.up, 500, accuracy: 0.001)    // (1500-500)/2
    }

    func testCounterResetYieldsZero() {
        let previous = NetworkSample(receivedBytes: 5000, sentBytes: 5000)
        let current = NetworkSample(receivedBytes: 100, sentBytes: 100)
        let rates = NetworkUsage.throughput(previous: previous, current: current, interval: 1)
        XCTAssertEqual(rates.down, 0)
        XCTAssertEqual(rates.up, 0)
    }

    func testNonPositiveIntervalYieldsZero() {
        let sample = NetworkSample(receivedBytes: 10, sentBytes: 10)
        let rates = NetworkUsage.throughput(previous: sample, current: sample, interval: 0)
        XCTAssertEqual(rates.down, 0)
        XCTAssertEqual(rates.up, 0)
    }
}
