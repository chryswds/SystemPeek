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
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: barHeight(i, t))
                }
            }
        }
    }

    private func barHeight(_ index: Int, _ t: Double) -> CGFloat {
        let v = (sin(t * 6 + Double(index) * 0.8) + 1) / 2     // 0...1
        return 4 + CGFloat(v) * 14
    }
}

/// The extended-notch strip shown while music is playing: artwork hugging the
/// left of the notch, the (empty) physical-notch gap in the middle, and a pulse
/// animation hugging the right. Sits on a continuous black notch-shaped strip.
struct MusicStripView: View {
    @ObservedObject var monitor: NowPlayingMonitor
    var notchWidth: CGFloat
    var height: CGFloat

    /// Must match NotchPanel's musicStripSize (notchWidth + 2 * sideExtension).
    static let sideExtension: CGFloat = 64
    private var artSize: CGFloat { max(height - 10, 16) }

    var body: some View {
        HStack(spacing: 0) {
            // Cover centered in the left extension (between the edge and the notch).
            artwork
                .frame(width: artSize, height: artSize)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .frame(width: Self.sideExtension, height: height)

            Color.clear.frame(width: notchWidth, height: height)

            HStack(spacing: 0) {
                PulseView(color: .brand)
                    .frame(height: artSize)
                    .padding(.leading, 11)
                Spacer(minLength: 0)
            }
            .frame(width: Self.sideExtension)
        }
        .frame(height: height)
        .background(NotchShape(bottomCornerRadius: 10).fill(Color.black))
    }

    @ViewBuilder private var artwork: some View {
        if let image = monitor.artwork {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color.white.opacity(0.12)
                Image(systemName: "music.note").font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
