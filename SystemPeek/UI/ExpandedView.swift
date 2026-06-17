import SwiftUI

extension Color {
    /// Shared usage colour ramp: green under 60%, yellow under 85%, red above.
    static func usage(_ percent: Double) -> Color {
        switch min(max(percent, 0), 100) {
        case ..<60: return .green
        case ..<85: return .yellow
        default: return .red
        }
    }
}

/// The drop-down panel contents: live CPU, memory, and disk usage with icons.
/// Observes the shared `MetricsSampler` so rows update as new samples arrive.
struct ExpandedView: View {
    @ObservedObject var sampler: MetricsSampler

    private var m: SystemMetrics { sampler.metrics }

    var body: some View {
        VStack(spacing: 14) {
            MetricRow(
                icon: "cpu",
                label: "CPU",
                percent: m.cpuPercent,
                detail: String(format: "%.0f%%", m.cpuPercent),
                identifier: "cpu"
            )
            MetricRow(
                icon: "memorychip",
                label: "Memory",
                percent: m.memoryPercent,
                detail: "\(ByteFormat.string(m.memoryUsedBytes)) / \(ByteFormat.string(m.memoryTotalBytes))",
                identifier: "memory"
            )
            MetricRow(
                icon: "internaldrive",
                label: "Disk",
                percent: m.diskPercent,
                detail: "\(ByteFormat.string(m.diskUsedBytes)) / \(ByteFormat.string(m.diskTotalBytes))",
                identifier: "disk"
            )
        }
        .padding(16)
        .frame(width: 300)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .accessibilityIdentifier("expandedPanel")
    }
}

/// A single labelled metric: icon, name, value detail, and a usage bar.
private struct MetricRow: View {
    let icon: String
    let label: String
    let percent: Double
    let detail: String
    let identifier: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.usage(percent))
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(detail)
                        .font(.system(size: 11, weight: .regular).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.65))
                        .accessibilityIdentifier("\(identifier).value")
                }
                UsageBar(percent: percent)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifier).row")
    }
}

/// A horizontal bar filled proportionally to `percent` (0...100), colour-coded.
private struct UsageBar: View {
    let percent: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule()
                    .fill(Color.usage(clamped))
                    .frame(width: geo.size.width * CGFloat(clamped / 100))
            }
        }
        .frame(height: 6)
    }

    private var clamped: Double { min(max(percent, 0), 100) }
}
