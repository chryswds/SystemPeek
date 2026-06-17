import XCTest
@testable import SystemPeek

final class MemoryUsageTests: XCTestCase {
    func testUsedBytesSumsActiveWiredCompressed() {
        let sample = MemorySample(
            activePages: 100,
            wiredPages: 50,
            compressedPages: 25,
            pageSize: 4096,
            totalBytes: 1 << 30
        )
        XCTAssertEqual(MemoryUsage.usedBytes(sample), 175 * 4096)
    }

    func testUsedNeverExceedsTotal() {
        // 100k pages * 4096 = ~409 MB of "used" against an 8 MB total.
        let sample = MemorySample(
            activePages: 100_000,
            wiredPages: 0,
            compressedPages: 0,
            pageSize: 4096,
            totalBytes: 8 * 1024 * 1024 // tiny total
        )
        XCTAssertEqual(MemoryUsage.usedBytes(sample), sample.totalBytes)
        XCTAssertLessThanOrEqual(MemoryUsage.usedBytes(sample), sample.totalBytes)
    }

    func testZeroPagesIsZero() {
        let sample = MemorySample(
            activePages: 0, wiredPages: 0, compressedPages: 0,
            pageSize: 16384, totalBytes: 1 << 30
        )
        XCTAssertEqual(MemoryUsage.usedBytes(sample), 0)
    }
}
