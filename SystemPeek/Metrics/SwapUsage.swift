import Foundation
import Darwin

/// Swap (compressed/virtual memory paged to disk) usage — a good sign of memory
/// pressure, and not shown in the standard UI.
struct SwapSample: Equatable {
    var usedBytes: UInt64
    var totalBytes: UInt64
}

enum SwapUsage {
    static func currentSample() -> SwapSample? {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return nil }
        return SwapSample(usedBytes: usage.xsu_used, totalBytes: usage.xsu_total)
    }
}
