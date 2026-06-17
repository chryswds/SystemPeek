import XCTest
@testable import SystemPeek

final class DiskUsageTests: XCTestCase {
    func testUsedBytesIsTotalMinusAvailable() {
        let sample = DiskSample(totalBytes: 100, availableBytes: 30)
        XCTAssertEqual(DiskUsage.usedBytes(sample), 70)
    }

    func testUsedNeverNegative() {
        let sample = DiskSample(totalBytes: 50, availableBytes: 80) // available > total
        XCTAssertEqual(DiskUsage.usedBytes(sample), 0)
    }

    // ByteFormat is part of the metrics-display layer.
    func testByteFormatting() {
        XCTAssertEqual(ByteFormat.string(Int64(0)), "0 B")
        XCTAssertEqual(ByteFormat.string(Int64(512)), "512 B")
        XCTAssertEqual(ByteFormat.string(Int64(1024)), "1.0 KB")
        XCTAssertEqual(ByteFormat.string(Int64(1536)), "1.5 KB")
        XCTAssertEqual(ByteFormat.string(Int64(512 * 1024 * 1024)), "512.0 MB")
        XCTAssertEqual(ByteFormat.string(Int64(8) * 1024 * 1024 * 1024), "8.0 GB")
        XCTAssertEqual(ByteFormat.string(Int64(2) * 1024 * 1024 * 1024 * 1024), "2.0 TB")
    }
}
