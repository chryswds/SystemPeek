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

/// Outline that makes the panel look like the notch expanding. The top is a
/// straight column the exact width (and height) of the notch — drawn over the
/// menu bar so it merges with the real notch — then concave "shoulders" flare it
/// out to the card's full width, with rounded convex bottom corners.
struct NotchExpandShape: Shape {
    var notchWidth: CGFloat
    var notchHeight: CGFloat        // height of the menu-bar/notch column at the top
    var shoulder: CGFloat = 22      // vertical depth of the concave flare
    var bottomRadius: CGFloat = 24

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let inset = max((rect.width - notchWidth) / 2, shoulder)
        let xL = rect.minX + inset          // left edge of the notch column
        let xR = rect.maxX - inset          // right edge of the notch column
        let neck = rect.minY + notchHeight  // where the flare begins

        // Flat top across the notch width.
        path.move(to: CGPoint(x: xL, y: rect.minY))
        path.addLine(to: CGPoint(x: xR, y: rect.minY))
        // Right notch side straight down to the neck.
        path.addLine(to: CGPoint(x: xR, y: neck))
        // Concave shoulder flaring out to the right edge.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: neck + shoulder),
            control: CGPoint(x: rect.maxX, y: neck)
        )
        // Right body side down to the rounded bottom-right.
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        // Bottom edge.
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        // Left body side up to the shoulder.
        path.addLine(to: CGPoint(x: rect.minX, y: neck + shoulder))
        // Concave shoulder flaring back in to the notch column.
        path.addQuadCurve(
            to: CGPoint(x: xL, y: neck),
            control: CGPoint(x: rect.minX, y: neck)
        )
        path.closeSubpath()
        return path
    }
}

/// The drop-down panel contents: live CPU, memory, and disk usage with icons.
/// Observes the shared `MetricsSampler` so rows update as new samples arrive.
struct ExpandedView: View {
    @ObservedObject var sampler: MetricsSampler
    var notchWidth: CGFloat = 200
    var notchHeight: CGFloat = 32

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
        // Content sits below the notch column + shoulder so it lands in the card body.
        .padding(EdgeInsets(top: notchHeight + 26, leading: 18, bottom: 20, trailing: 18))
        .frame(width: 320)
        .background(
            NotchExpandShape(notchWidth: notchWidth, notchHeight: notchHeight)
                .fill(Color.black)
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
