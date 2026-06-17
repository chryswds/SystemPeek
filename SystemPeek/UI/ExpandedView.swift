import SwiftUI

/// The expanded panel contents: live CPU, memory, and disk usage. Observes the
/// shared `MetricsSampler` so rows update as new samples arrive.
struct ExpandedView: View {
    @ObservedObject var sampler: MetricsSampler

    private var m: SystemMetrics { sampler.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetricRow(
                label: "CPU",
                percent: m.cpuPercent,
                detail: String(format: "%.0f%%", m.cpuPercent),
                identifier: "cpu"
            )
            MetricRow(
                label: "Memory",
                percent: m.memoryPercent,
                detail: "\(ByteFormat.string(m.memoryUsedBytes)) / \(ByteFormat.string(m.memoryTotalBytes))",
                identifier: "memory"
            )
            MetricRow(
                label: "Disk",
                percent: m.diskPercent,
                detail: "\(ByteFormat.string(m.diskUsedBytes)) / \(ByteFormat.string(m.diskTotalBytes))",
                identifier: "disk"
            )
        }
        .padding(14)
        .frame(width: 290)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("expandedPanel")
    }
}

/// A single labelled metric: name, value detail, and a proportional usage bar.
private struct MetricRow: View {
    let label: String
    let percent: Double
    let detail: String
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(detail)
                    .font(.system(size: 11, weight: .regular).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityIdentifier("\(identifier).value")
            }
            UsageBar(percent: percent)
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
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(clamped / 100))
            }
        }
        .frame(height: 6)
    }

    private var clamped: Double { min(max(percent, 0), 100) }

    private var color: Color {
        switch clamped {
        case ..<60: return .green
        case ..<85: return .yellow
        default: return .red
        }
    }
}
