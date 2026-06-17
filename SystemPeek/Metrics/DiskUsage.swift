import Foundation

/// Capacity of a volume in bytes.
struct DiskSample: Equatable {
    var totalBytes: Int64
    var availableBytes: Int64
}

enum DiskUsage {
    /// Pure: used bytes = total - available, never negative.
    static func usedBytes(_ sample: DiskSample) -> Int64 {
        max(sample.totalBytes - sample.availableBytes, 0)
    }

    /// Reads capacity for the volume at `path` (root by default), or nil.
    static func currentSample(path: String = "/") -> DiskSample? {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]) else { return nil }

        let total = Int64(values.volumeTotalCapacity ?? 0)
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        return DiskSample(totalBytes: total, availableBytes: available)
    }
}
