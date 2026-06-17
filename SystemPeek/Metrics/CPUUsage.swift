import Foundation
import Darwin

/// Aggregate CPU tick counters from `host_statistics(HOST_CPU_LOAD_INFO)`.
struct CPUTicks: Equatable {
    var user: UInt32
    var system: UInt32
    var idle: UInt32
    var nice: UInt32

    var total: UInt64 { UInt64(user) + UInt64(system) + UInt64(idle) + UInt64(nice) }
    var busy: UInt64 { UInt64(user) + UInt64(system) + UInt64(nice) }
}

enum CPUUsage {
    /// Pure: busy percentage between two tick snapshots.
    ///
    /// Returns 0 when no time elapsed or counters moved backwards (wraparound),
    /// and clamps the result to `0...100`.
    static func busyPercent(previous: CPUTicks, current: CPUTicks) -> Double {
        let totalDelta = Int64(current.total) - Int64(previous.total)
        let busyDelta = Int64(current.busy) - Int64(previous.busy)
        guard totalDelta > 0, busyDelta >= 0 else { return 0 }
        let percent = Double(busyDelta) / Double(totalDelta) * 100
        return min(max(percent, 0), 100)
    }

    /// Reads the current aggregate CPU ticks from the kernel, or nil on failure.
    static func currentTicks() -> CPUTicks? {
        // HOST_CPU_LOAD_INFO_COUNT isn't imported into Swift; derive it.
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        var info = host_cpu_load_info()
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        // cpu_ticks is a 4-tuple indexed by CPU_STATE_{USER,SYSTEM,IDLE,NICE}.
        let ticks = info.cpu_ticks
        return CPUTicks(user: ticks.0, system: ticks.1, idle: ticks.2, nice: ticks.3)
    }
}
