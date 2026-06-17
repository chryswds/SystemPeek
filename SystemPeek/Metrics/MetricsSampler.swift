import Foundation
import Combine

/// Samples system telemetry on a timer and publishes the latest `SystemMetrics`
/// for the UI to observe.
@MainActor
final class MetricsSampler: ObservableObject {
    @Published private(set) var metrics: SystemMetrics = .zero

    private var timer: Timer?
    private var previousTicks: CPUTicks?

    init() {
        // Prime the CPU baseline so the first interval yields a real percentage.
        previousTicks = CPUUsage.currentTicks()
        sample()
    }

    /// Begin sampling every `interval` seconds (default 1s).
    func start(interval: TimeInterval = 1.0) {
        stop()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Take one sample, updating `metrics`. Safe to call directly (used by tests).
    func sample() {
        var next = metrics

        if let current = CPUUsage.currentTicks() {
            if let previous = previousTicks {
                next.cpuPercent = CPUUsage.busyPercent(previous: previous, current: current)
            }
            previousTicks = current
        }

        if let memory = MemoryUsage.currentSample() {
            next.memoryUsedBytes = MemoryUsage.usedBytes(memory)
            next.memoryTotalBytes = memory.totalBytes
        }

        if let disk = DiskUsage.currentSample() {
            next.diskUsedBytes = DiskUsage.usedBytes(disk)
            next.diskTotalBytes = disk.totalBytes
        }

        metrics = next
    }

    deinit {
        timer?.invalidate()
    }
}
