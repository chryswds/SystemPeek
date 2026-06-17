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

/// Outline that makes the panel look like the notch expanding: a flat top the
/// width of the notch (flush with the menu bar), concave "shoulders" flaring out
/// to the card's full width, then straight sides into rounded bottom corners.
struct NotchExpandShape: Shape {
    var notchWidth: CGFloat
    var shoulder: CGFloat = 16      // depth of the concave flare
    var bottomRadius: CGFloat = 22

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let topInset = max((rect.width - notchWidth) / 2, shoulder)
        let leftTopX = rect.minX + topInset
        let rightTopX = rect.maxX - topInset

        // Flat top starts at the left end (under the notch).
        path.move(to: CGPoint(x: leftTopX, y: rect.minY))
        // Concave shoulder flaring out to the left edge.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + shoulder),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        // Left side down to the bottom-left corner.
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - bottomRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + bottomRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        // Bottom edge.
        path.addLine(to: CGPoint(x: rect.maxX - bottomRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRadius),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        // Right side up.
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + shoulder))
        // Concave shoulder flaring back in to the flat top.
        path.addQuadCurve(
            to: CGPoint(x: rightTopX, y: rect.minY),
            control: CGPoint(x: rect.maxX, y: rect.minY)
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
        .padding(EdgeInsets(top: 20, leading: 18, bottom: 18, trailing: 18))
        .frame(width: 320)
        .background(
            NotchExpandShape(notchWidth: notchWidth)
                .fill(Color.black)
                .overlay(
                    NotchExpandShape(notchWidth: notchWidth)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
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
