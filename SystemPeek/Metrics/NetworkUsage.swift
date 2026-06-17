import Foundation
import Darwin

/// Cumulative interface byte counters (received / sent).
struct NetworkSample: Equatable {
    var receivedBytes: UInt64
    var sentBytes: UInt64
}

enum NetworkUsage {
    /// Pure: bytes-per-second between two samples. Counter resets/wraps (current
    /// below previous) yield 0, and a non-positive interval yields 0.
    static func throughput(previous: NetworkSample, current: NetworkSample, interval: TimeInterval) -> (down: Double, up: Double) {
        guard interval > 0 else { return (0, 0) }
        let down = current.receivedBytes >= previous.receivedBytes ? current.receivedBytes - previous.receivedBytes : 0
        let up = current.sentBytes >= previous.sentBytes ? current.sentBytes - previous.sentBytes : 0
        return (Double(down) / interval, Double(up) / interval)
    }

    /// Sums received/sent bytes across all non-loopback link-layer interfaces.
    static func currentSample() -> NetworkSample? {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0 else { return nil }
        defer { freeifaddrs(addrs) }

        var received: UInt64 = 0
        var sent: UInt64 = 0
        var pointer = addrs
        while let current = pointer {
            let interface = current.pointee
            if let addr = interface.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_LINK),
               !String(cString: interface.ifa_name).hasPrefix("lo"),
               let data = interface.ifa_data {
                let stats = data.assumingMemoryBound(to: if_data.self).pointee
                received += UInt64(stats.ifi_ibytes)
                sent += UInt64(stats.ifi_obytes)
            }
            pointer = interface.ifa_next
        }
        return NetworkSample(receivedBytes: received, sentBytes: sent)
    }
}
