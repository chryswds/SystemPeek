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

    @AppStorage(MetricKey.cpu) private var showCPU = true
    @AppStorage(MetricKey.memory) private var showMemory = true
    @AppStorage(MetricKey.disk) private var showDisk = true
    @AppStorage(MetricKey.network) private var showNetwork = true
    @AppStorage(MetricKey.load) private var showLoad = true
    @AppStorage(MetricKey.swap) private var showSwap = true
    @AppStorage(MetricKey.topCPU) private var showTopCPU = true
    @AppStorage(MetricKey.topMemory) private var showTopMemory = true

    private var m: SystemMetrics { sampler.metrics }

    private var topRowVisible: Bool { showCPU || showMemory || showDisk }
    private var bottomVisible: Bool {
        showNetwork || showLoad || showSwap || showTopCPU || showTopMemory
    }

    private func percentString(_ value: Double) -> String { String(format: "%.0f%%", value) }
    private func rate(_ bytesPerSecond: Double) -> String {
        ByteFormat.string(Int64(max(bytesPerSecond, 0))) + "/s"
    }


    var body: some View {
        VStack(spacing: 12) {
            if topRowVisible {
                HStack(alignment: .top, spacing: 12) {
                    if showCPU {
                        StatCell(icon: "cpu", label: "CPU",
                                 value: percentString(m.cpuPercent), percent: m.cpuPercent,
                                 identifier: "cpu")
                    }
                    if showMemory {
                        StatCell(icon: "memorychip", label: "Memory",
                                 value: percentString(m.memoryPercent), percent: m.memoryPercent,
                                 identifier: "memory",
                                 hoverDetail: "\(ByteFormat.string(m.memoryUsedBytes)) / \(ByteFormat.string(m.memoryTotalBytes))")
                    }
                    if showDisk {
                        StatCell(icon: "internaldrive", label: "Disk",
                                 value: percentString(m.diskPercent), percent: m.diskPercent,
                                 identifier: "disk",
                                 hoverDetail: "\(ByteFormat.string(m.diskUsedBytes)) / \(ByteFormat.string(m.diskTotalBytes))")
                    }
                }
            }

            if topRowVisible && bottomVisible {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }

            if showNetwork {
                NetworkRow(down: rate(m.networkDownBytesPerSec),
                           up: rate(m.networkUpBytesPerSec))
            }

            if showLoad || showSwap {
                HStack(spacing: 24) {
                    if showLoad {
                        InfoItem(label: "Load",
                                 value: String(format: "%.2f  %.2f  %.2f", m.loadOne, m.loadFive, m.loadFifteen))
                    }
                    if showSwap {
                        InfoItem(label: "Swap", value: ByteFormat.string(m.swapUsedBytes))
                    }
                }
            }

            if showTopCPU {
                HighlightItem(icon: "cpu", title: "Top CPU",
                              name: m.topCPUName.isEmpty ? "—" : m.topCPUName,
                              value: m.topCPUName.isEmpty ? "" : String(format: "%.0f%%", m.topCPUPercent),
                              valueColor: .usage(m.topCPUPercent))
            }
            if showTopMemory {
                HighlightItem(icon: "memorychip", title: "Top Mem",
                              name: m.topMemoryName.isEmpty ? "—" : m.topMemoryName,
                              value: m.topMemoryName.isEmpty ? "" : ByteFormat.string(m.topMemoryBytes),
                              valueColor: Color(red: 0.46, green: 0.78, blue: 1.0))
            }
        }
        // Clear the menu-bar height at the top so content sits below it.
        // No background here: the morphing black NotchShape is drawn behind this
        // (in NotchPanel) so the shape can resize independently of the metrics.
        .padding(EdgeInsets(top: topInset + 16, leading: 28, bottom: 22, trailing: 28))
        .frame(width: 480)
        .fixedSize()
        .accessibilityIdentifier("expandedPanel")
    }
}

/// A highlighted full-width chip for the top-process rows: icon + title, the
/// process name, and a bold colour-coded value, on a subtle rounded background.
private struct HighlightItem: View {
    let icon: String
    let title: String
    let name: String
    let value: String
    var valueColor: Color = .white

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 16)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Spacer(minLength: 8)
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(value)
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(valueColor)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}

/// A compact label/value pair that fills half the width in the info grid.
private struct InfoItem: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 12, weight: .regular).monospacedDigit())
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(.white)
    }
}

/// A grid cell with an icon, label, percentage value, and a usage bar.
private struct StatCell: View {
    let icon: String
    let label: String
    let value: String
    let percent: Double
    let identifier: String
    var tint: Color? = nil
    /// Shown in place of `value` while the cursor hovers this cell (e.g. GB used/total).
    var hoverDetail: String? = nil

    @State private var hovering = false
    private var color: Color { tint ?? .usage(percent) }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 18)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 4)
                Text(value)
                    .font(.system(size: 12, weight: .regular).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.7))
                    .accessibilityIdentifier("\(identifier).value")
            }
            // While hovering, the actual amount is shown inside the (taller) bar.
            UsageBar(percent: percent, tint: color, overlay: hovering ? hoverDetail : nil)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
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
    var tint: Color
    /// Optional text drawn inside the bar (e.g. the actual amount, shown on hover).
    var overlay: String? = nil

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule()
                    .fill(tint)
                    .frame(width: geo.size.width * CGFloat(clamped / 100))

                if let overlay {
                    // A soft dark scrim so the amount reads cleanly over any fill colour.
                    ZStack {
                        Capsule().fill(.black.opacity(0.40))
                        Text(overlay)
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 10)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.16), value: overlay)
        }
        .frame(height: 18)
    }

    private var clamped: Double { min(max(percent, 0), 100) }
}
