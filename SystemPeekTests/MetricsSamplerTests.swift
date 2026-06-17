import XCTest
@testable import SystemPeek

/// Integration tests: exercise the real Darwin readers and assert the published
/// snapshot is internally consistent and within sane ranges on the test host.
@MainActor
final class MetricsSamplerTests: XCTestCase {
    func testRealSampleIsInSaneRanges() {
        let sampler = MetricsSampler()
        sampler.sample()
        let m = sampler.metrics

        XCTAssertGreaterThanOrEqual(m.cpuPercent, 0)
        XCTAssertLessThanOrEqual(m.cpuPercent, 100)

        XCTAssertGreaterThan(m.memoryTotalBytes, 0)
        XCTAssertLessThanOrEqual(m.memoryUsedBytes, m.memoryTotalBytes)

        XCTAssertGreaterThan(m.diskTotalBytes, 0)
        XCTAssertGreaterThanOrEqual(m.diskUsedBytes, 0)
        XCTAssertLessThanOrEqual(m.diskUsedBytes, m.diskTotalBytes)

        XCTAssertGreaterThanOrEqual(m.networkDownBytesPerSec, 0)
        XCTAssertGreaterThanOrEqual(m.networkUpBytesPerSec, 0)
    }

    func testRepeatedSamplingStaysConsistent() {
        let sampler = MetricsSampler()
        sampler.sample()
        let first = sampler.metrics
        sampler.sample()
        let second = sampler.metrics

        // Totals are stable across samples; nothing crashes or goes out of range.
        XCTAssertEqual(first.memoryTotalBytes, second.memoryTotalBytes)
        XCTAssertEqual(first.diskTotalBytes, second.diskTotalBytes)
        XCTAssertLessThanOrEqual(second.cpuPercent, 100)
        XCTAssertGreaterThanOrEqual(second.cpuPercent, 0)
    }
}
