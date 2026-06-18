import SwiftUI

/// Decorative pulsing bars (not driven by real audio) shown while music plays.
struct PulseView: View {
    var color: Color = .white
    var barCount = 4

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    Capsule().fill(color).frame(width: 3, height: barHeight(i, t))
                }
            }
        }
    }

    private func barHeight(_ index: Int, _ t: Double) -> CGFloat {
        let v = (sin(t * 6 + Double(index) * 0.8) + 1) / 2
        return 4 + CGFloat(v) * 14
    }
}

/// The extended-notch header strip: the album cover lives in the left extension
/// (rendered as a positioned overlay by NotchContentView), the notch gap, and the
/// pulse on the right.
struct MusicStripView: View {
    @ObservedObject var monitor: NowPlayingMonitor
    var notchWidth: CGFloat
    var height: CGFloat

    /// Must match NotchPanel's musicStripSize (notchWidth + 2 * sideExtension).
    static let sideExtension: CGFloat = 64
    static var coverSize: (CGFloat) -> CGFloat = { max($0 - 10, 16) }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: Self.sideExtension, height: height)   // cover overlay sits here
            Color.clear.frame(width: notchWidth, height: height)
            HStack(spacing: 0) {
                PulseView(color: .brand)
                    .frame(height: Self.coverSize(height))
                    .padding(.leading, 11)
                    .opacity(monitor.isPlaying ? 1 : 0.35)
                Spacer(minLength: 0)
            }
            .frame(width: Self.sideExtension)
        }
        .frame(height: height)
        .background(NotchShape(bottomCornerRadius: 10).fill(Color.black))
    }
}
