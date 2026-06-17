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

/// The notch shape: a rounded rectangle attached to the top edge of the screen,
/// with inverted (concave) top corners that melt into the bezel and rounded
/// convex bottom corners — so the panel reads as the notch widened into an island.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat = 14
    var bottomCornerRadius: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tr = min(topCornerRadius, rect.width / 2)
        let br = min(bottomCornerRadius, rect.width / 2)

        // Top edge runs the full width; the corners curve inward to meet it.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Inverted top-left corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
            control: CGPoint(x: rect.minX + tr, y: rect.minY)
        )
        // Left side down to the convex bottom-left corner.
        path.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
            control: CGPoint(x: rect.minX + tr, y: rect.maxY)
        )
        // Bottom edge.
        path.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
            control: CGPoint(x: rect.maxX - tr, y: rect.maxY)
        )
        // Right side up to the inverted top-right corner.
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - tr, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

/// The drop-down panel contents: live CPU, memory, and disk usage with icons.
/// Observes the shared `MetricsSampler` so rows update as new samples arrive.
struct ExpandedView: View {
    @ObservedObject var sampler: MetricsSampler
    /// Menu-bar/notch height to clear at the top so content sits in the visible area.
    var topInset: CGFloat = 32

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
        // Clear the menu-bar height at the top so content sits below it.
        .padding(EdgeInsets(top: topInset + 8, leading: 22, bottom: 20, trailing: 22))
        .frame(width: 340)
        .background(
            NotchShape().fill(Color.black)
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
