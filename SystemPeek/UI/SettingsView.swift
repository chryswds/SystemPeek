import SwiftUI

/// Keys for the per-metric visibility toggles (all default on).
enum MetricKey {
    static let cpu = "showCPU"
    static let memory = "showMemory"
    static let disk = "showDisk"
    static let network = "showNetwork"
    static let load = "showLoad"
    static let swap = "showSwap"
    static let topCPU = "showTopCPU"
    static let topMemory = "showTopMemory"
}

/// The app's settings window: choose which metrics appear on the island.
struct SettingsView: View {
    @AppStorage(MetricKey.cpu) private var showCPU = true
    @AppStorage(MetricKey.memory) private var showMemory = true
    @AppStorage(MetricKey.disk) private var showDisk = true
    @AppStorage(MetricKey.network) private var showNetwork = true
    @AppStorage(MetricKey.load) private var showLoad = true
    @AppStorage(MetricKey.swap) private var showSwap = true
    @AppStorage(MetricKey.topCPU) private var showTopCPU = true
    @AppStorage(MetricKey.topMemory) private var showTopMemory = true

    var body: some View {
        Form {
            Section("Metrics shown on the island") {
                Toggle("CPU", isOn: $showCPU)
                Toggle("Memory", isOn: $showMemory)
                Toggle("Disk", isOn: $showDisk)
                Toggle("Network", isOn: $showNetwork)
                Toggle("Load average", isOn: $showLoad)
                Toggle("Swap", isOn: $showSwap)
                Toggle("Top process by CPU", isOn: $showTopCPU)
                Toggle("Top process by memory", isOn: $showTopMemory)
            }
        }
        .formStyle(.grouped)
        .frame(width: 340, height: 380)
    }
}
