import Foundation
import Darwin

/// System load average over 1, 5, and 15 minutes — the kernel's run-queue
/// pressure, not surfaced anywhere in the standard UI.
enum LoadAverage {
    static func current() -> (one: Double, five: Double, fifteen: Double)? {
        var loads = [Double](repeating: 0, count: 3)
        guard getloadavg(&loads, 3) == 3 else { return nil }
        return (loads[0], loads[1], loads[2])
    }
}
