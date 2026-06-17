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

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 12) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 44, height: 44)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SystemPeek")
                            .font(.headline)
                        Text(versionText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }

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
