import XCTest
@testable import SystemPeek

final class ProcessUsageTests: XCTestCase {
    private func sample(_ pid: pid_t, _ name: String, cpu: Double = 0, mem: UInt64 = 0) -> ProcessSample {
        ProcessSample(pid: pid, name: name, cpuSeconds: cpu, memoryBytes: mem)
    }

    func testTopByMemoryPicksLargest() {
        let processes = [sample(1, "A", mem: 100), sample(2, "B", mem: 500), sample(3, "C", mem: 300)]
        let top = ProcessUsage.topByMemory(processes)
        XCTAssertEqual(top?.name, "B")
        XCTAssertEqual(top?.bytes, 500)
    }

    func testTopByMemoryEmptyIsNil() {
        XCTAssertNil(ProcessUsage.topByMemory([]))
    }

    func testTopByCPUUsesDeltaOverInterval() {
        let previous: [pid_t: Double] = [1: 10, 2: 20]
        let current = [sample(1, "A", cpu: 14), sample(2, "B", cpu: 21)] // +4/2s=200%, +1/2s=50%
        let top = ProcessUsage.topByCPU(previous: previous, current: current, interval: 2)
        XCTAssertEqual(top?.name, "A")
        XCTAssertEqual(top?.percent ?? 0, 200, accuracy: 0.001)
    }

    func testTopByCPUIgnoresUnknownAndNonPositiveDeltas() {
        let previous: [pid_t: Double] = [1: 10]
        let current = [sample(1, "A", cpu: 10), sample(9, "New", cpu: 5)] // delta 0, and no baseline
        XCTAssertNil(ProcessUsage.topByCPU(previous: previous, current: current, interval: 1))
    }

    func testTopByCPUZeroIntervalIsNil() {
        XCTAssertNil(ProcessUsage.topByCPU(previous: [1: 1], current: [sample(1, "A", cpu: 5)], interval: 0))
    }
}
