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
        // Clamp so the shape stays valid even at the tiny notch size during the
        // morph (top + bottom radii must fit within the height and width).
        let tr = min(topCornerRadius, rect.width / 2, rect.height / 2)
        let br = min(bottomCornerRadius, rect.width / 2, max(rect.height - tr, 0))

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

/// The drop-down panel contents: live system telemetry laid out as a 2x2 grid
/// (CPU + Memory on top, Disk + Network below) with a thin divider between rows.
struct ExpandedView: View {
    @ObservedObject var sampler: MetricsSampler
    /// Menu-bar/notch height to clear at the top so content sits in the visible area.
    var topInset: CGFloat = 32

    private var m: SystemMetrics { sampler.metrics }

    private func percentString(_ value: Double) -> String { String(format: "%.0f%%", value) }
    private func rate(_ bytesPerSecond: Double) -> String {
        ByteFormat.string(Int64(max(bytesPerSecond, 0))) + "/s"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                StatCell(icon: "cpu", label: "CPU",
                         value: percentString(m.cpuPercent), percent: m.cpuPercent,
                         identifier: "cpu")
                StatCell(icon: "memorychip", label: "Memory",
                         value: percentString(m.memoryPercent), percent: m.memoryPercent,
                         identifier: "memory")
                StatCell(icon: "internaldrive", label: "Disk",
                         value: percentString(m.diskPercent), percent: m.diskPercent,
                         identifier: "disk")
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            NetworkRow(down: rate(m.networkDownBytesPerSec),
                       up: rate(m.networkUpBytesPerSec))
        }
        // Clear the menu-bar height at the top so content sits below it.
        // No background here: the morphing black NotchShape is drawn behind this
        // (in NotchPanel) so the shape can resize independently of the metrics.
        .padding(EdgeInsets(top: topInset + 10, leading: 20, bottom: 16, trailing: 20))
        .frame(width: 460)
        .fixedSize()
        .accessibilityIdentifier("expandedPanel")
    }
}

/// A grid cell with an icon, label, percentage value, and a usage bar.
private struct StatCell: View {
    let icon: String
    let label: String
    let value: String
    let percent: Double
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.usage(percent))
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 12, weight: .regular).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityIdentifier("\(identifier).value")
            }
            UsageBar(percent: percent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(identifier).row")
    }
}

/// The network row, spanning the full width: icon + label on the left,
/// download/upload rates on the right.
private struct NetworkRow: View {
    let down: String
    let up: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 18)
            Text("Network")
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 8)
            HStack(spacing: 16) {
                Text("↓ \(down)")
                Text("↑ \(up)")
            }
            .font(.system(size: 12, weight: .regular).monospacedDigit())
            .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("network.row")
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
