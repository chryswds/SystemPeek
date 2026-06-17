import Foundation
import IOKit.ps

/// Battery state: charge percentage, whether it's charging, and whether a battery
/// is even present (false on desktops).
struct BatterySample: Equatable {
    var percent: Double
    var isCharging: Bool
    var isPresent: Bool
}

enum BatteryUsage {
    /// Pure: capacity as a percentage of max, clamped to 0...100.
    static func percent(current: Int, max: Int) -> Double {
        guard max > 0 else { return 0 }
        return min(Double(current) / Double(max) * 100, 100)
    }

    /// Reads the internal battery via IOKit power sources (no entitlement needed).
    static func currentSample() -> BatterySample? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else {
                continue
            }
            let current = info[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = info[kIOPSMaxCapacityKey] as? Int ?? 100
            let charging = (info[kIOPSIsChargingKey] as? Bool) ?? false
            return BatterySample(percent: percent(current: current, max: maximum),
                                 isCharging: charging, isPresent: true)
        }
        return BatterySample(percent: 0, isCharging: false, isPresent: false)
    }
}
