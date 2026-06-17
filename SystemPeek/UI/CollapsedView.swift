import SwiftUI

/// The collapsed look: a slim black strip that visually extends the notch,
/// carrying three small colour-coded dots (CPU, memory, disk) so the current
/// state is legible at a glance without expanding.
struct CollapsedView: View {
    @ObservedObject var sampler: MetricsSampler

    private var m: SystemMetrics { sampler.metrics }

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(percent: m.cpuPercent)
            StatusDot(percent: m.memoryPercent)
            StatusDot(percent: m.diskPercent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            UnevenRoundedRectangle(
                bottomLeadingRadius: 10,
                bottomTrailingRadius: 10,
                style: .continuous
            )
            .fill(Color.black)
        )
        .accessibilityIdentifier("collapsedStrip")
    }
}

private struct StatusDot: View {
    let percent: Double

    var body: some View {
        Circle()
            .fill(Color.usage(percent))
            .frame(width: 6, height: 6)
    }
}
