import Foundation

/// A single snapshot of the system telemetry SystemPeek displays.
struct SystemMetrics: Equatable {
    /// Overall CPU busy percentage in `0...100`.
    var cpuPercent: Double
    var memoryUsedBytes: UInt64
    var memoryTotalBytes: UInt64
    var diskUsedBytes: Int64
    var diskTotalBytes: Int64
    var networkDownBytesPerSec: Double = 0
    var networkUpBytesPerSec: Double = 0
    var loadOne: Double = 0
    var loadFive: Double = 0
    var loadFifteen: Double = 0
    var swapUsedBytes: UInt64 = 0
    var swapTotalBytes: UInt64 = 0
    var topCPUName: String = ""
    var topCPUPercent: Double = 0
    var topMemoryName: String = ""
    var topMemoryBytes: UInt64 = 0

    static let zero = SystemMetrics(
        cpuPercent: 0,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        diskUsedBytes: 0,
        diskTotalBytes: 0
    )

    var memoryPercent: Double {
        memoryTotalBytes > 0
            ? Double(memoryUsedBytes) / Double(memoryTotalBytes) * 100
            : 0
    }

    var diskPercent: Double {
        diskTotalBytes > 0
            ? Double(diskUsedBytes) / Double(diskTotalBytes) * 100
            : 0
    }
}

/// Deterministic, locale-independent byte formatting for the UI (binary units).
enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = Double(max(bytes, 0))
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        // Whole numbers for bytes, one decimal place for KB and up.
        let format = index == 0 ? "%.0f %@" : "%.1f %@"
        return String(format: format, value, units[index])
    }

    static func string(_ bytes: UInt64) -> String { string(Int64(min(bytes, UInt64(Int64.max)))) }
}
