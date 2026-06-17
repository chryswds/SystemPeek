import Foundation
import Darwin

/// A single process snapshot: name, cumulative CPU seconds, and memory footprint.
struct ProcessSample: Equatable {
    var pid: pid_t
    var name: String
    var cpuSeconds: Double
    var memoryBytes: UInt64
}

enum ProcessUsage {
    /// Pure: the process using the most memory.
    static func topByMemory(_ processes: [ProcessSample]) -> (name: String, bytes: UInt64)? {
        guard let top = processes.max(by: { $0.memoryBytes < $1.memoryBytes }) else { return nil }
        return (top.name, top.memoryBytes)
    }

    /// Pure: the process with the highest CPU% between two snapshots, using the
    /// previous cumulative CPU seconds keyed by pid. Processes with no previous
    /// sample or a non-positive delta are ignored.
    static func topByCPU(previous: [pid_t: Double], current: [ProcessSample], interval: TimeInterval) -> (name: String, percent: Double)? {
        guard interval > 0 else { return nil }
        var best: (name: String, percent: Double)?
        for process in current {
            guard let previousSeconds = previous[process.pid] else { continue }
            let delta = process.cpuSeconds - previousSeconds
            guard delta > 0 else { continue }
            let percent = delta / interval * 100
            if percent > (best?.percent ?? 0) { best = (process.name, percent) }
        }
        return best
    }

    /// Snapshot all processes' name, cumulative CPU seconds, and memory footprint.
    /// Requires the App Sandbox to be disabled (process enumeration is blocked
    /// under the sandbox).
    static func snapshot() -> [ProcessSample] {
        let needed = proc_listpids(UInt32(1 /* PROC_ALL_PIDS */), 0, nil, 0)
        guard needed > 0 else { return [] }
        let capacity = Int(needed) / MemoryLayout<pid_t>.size
        var pids = [pid_t](repeating: 0, count: capacity)
        let written = proc_listpids(UInt32(1), 0, &pids, Int32(capacity * MemoryLayout<pid_t>.size))
        guard written > 0 else { return [] }
        let count = Int(written) / MemoryLayout<pid_t>.size

        var samples: [ProcessSample] = []
        samples.reserveCapacity(count)
        for pid in pids.prefix(count) where pid > 0 {
            var usage = rusage_info_v4()
            let result = withUnsafeMutablePointer(to: &usage) { pointer in
                pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
                }
            }
            guard result == 0 else { continue }

            var nameBuffer = [CChar](repeating: 0, count: 256)
            let nameLength = proc_name(pid, &nameBuffer, UInt32(nameBuffer.count))
            let name = nameLength > 0 ? String(cString: nameBuffer) : "pid \(pid)"

            // ri_user_time / ri_system_time are nanoseconds.
            let cpuSeconds = Double(usage.ri_user_time + usage.ri_system_time) / 1_000_000_000
            samples.append(ProcessSample(pid: pid, name: name,
                                         cpuSeconds: cpuSeconds, memoryBytes: usage.ri_phys_footprint))
        }
        return samples
    }
}
