import Foundation
import Darwin

/// A raw memory snapshot in pages, plus page size and physical total.
struct MemorySample: Equatable {
    var activePages: UInt64
    var wiredPages: UInt64
    var compressedPages: UInt64
    var pageSize: UInt64
    var totalBytes: UInt64
}

enum MemoryUsage {
    /// Pure: used bytes = (active + wired + compressed) * pageSize, clamped to
    /// the physical total. This mirrors what Activity Monitor counts as in-use.
    static func usedBytes(_ sample: MemorySample) -> UInt64 {
        let pages = sample.activePages + sample.wiredPages + sample.compressedPages
        let used = pages * sample.pageSize
        return min(used, sample.totalBytes)
    }

    /// Reads current VM statistics + physical memory size, or nil on failure.
    static func currentSample() -> MemorySample? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var total: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &total, &size, nil, 0)

        return MemorySample(
            activePages: UInt64(stats.active_count),
            wiredPages: UInt64(stats.wire_count),
            compressedPages: UInt64(stats.compressor_page_count),
            pageSize: UInt64(vm_kernel_page_size),
            totalBytes: total
        )
    }
}
