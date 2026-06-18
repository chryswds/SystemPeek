import SwiftUI

/// The music-control page: large album cover (a matched-geometry slot the hero
/// cover snaps into), track info, a seekable progress bar, transport controls,
/// shuffle/repeat, and a volume slider. Shows a placeholder when nothing plays.
struct MusicControlView: View {
    @ObservedObject var monitor: NowPlayingMonitor
    var coverSize: CGFloat           // reserved space for the cover overlay
    var topInset: CGFloat

    var body: some View {
        Group {
            if let info = monitor.info {
                content(info)
            } else {
                placeholder
            }
        }
        .padding(EdgeInsets(top: topInset + 6, leading: 24, bottom: 16, trailing: 24))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .foregroundStyle(.white)
    }

    private func content(_ info: NowPlayingInfo) -> some View {
        HStack(alignment: .center, spacing: 16) {
            // Reserved space for the hero cover overlay (positioned by NotchContentView).
            Color.clear.frame(width: coverSize, height: coverSize)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                    Text(info.artist).font(.system(size: 12)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                    Text(info.album).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }

                ScrubBar(position: info.position, duration: info.duration) { monitor.seek(to: $0) }

                transport(info)

                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                    VolumeBar(volume: info.volume) { monitor.setVolume($0) }
                    Image(systemName: "speaker.wave.3.fill").font(.system(size: 9)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    private func transport(_ info: NowPlayingInfo) -> some View {
        HStack(spacing: 18) {
            Button { monitor.toggleShuffle() } label: {
                Image(systemName: "shuffle")
                    .foregroundStyle(info.shuffle ? Color.brand : .white.opacity(0.7))
                    .frame(width: 22, height: 22)
            }
            Spacer(minLength: 0)
            Button { monitor.previous() } label: {
                Image(systemName: "backward.fill").frame(width: 24, height: 24)
            }
            Button { monitor.togglePlayPause() } label: {
                Image(systemName: info.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 19))
                    .frame(width: 26, height: 26)
            }
            Button { monitor.next() } label: {
                Image(systemName: "forward.fill").frame(width: 24, height: 24)
            }
            Spacer(minLength: 0)
            Button { monitor.cycleRepeat() } label: {
                Image(systemName: info.repeatMode == .one ? "repeat.1" : "repeat")
                    .foregroundStyle(info.repeatMode == .off ? .white.opacity(0.7) : Color.brand)
                    .frame(width: 22, height: 22)
            }
        }
        .font(.system(size: 15))
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "music.note").font(.system(size: 28)).foregroundStyle(.white.opacity(0.4))
            Text("Nothing playing").font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            Text("Apple Music or Spotify").font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// A seekable progress bar with elapsed / total time labels.
private struct ScrubBar: View {
    let position: Double
    let duration: Double
    let onSeek: (Double) -> Void
    @State private var dragValue: Double?

    private var shown: Double { dragValue ?? position }
    private var fraction: Double { duration > 0 ? min(max(shown / duration, 0), 1) : 0 }

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.15))
                    Capsule().fill(Color.brand).frame(width: geo.size.width * fraction)
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    dragValue = max(0, min(1, g.location.x / geo.size.width)) * duration
                }.onEnded { _ in
                    if let v = dragValue { onSeek(v) }
                    dragValue = nil
                })
            }
            .frame(height: 12)
            HStack {
                Text(timeString(shown)).font(.system(size: 9).monospacedDigit()).foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(timeString(duration)).font(.system(size: 9).monospacedDigit()).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(max(0, seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// A draggable volume bar (0...100).
private struct VolumeBar: View {
    let volume: Double
    let onChange: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.15))
                Capsule().fill(.white.opacity(0.7)).frame(width: geo.size.width * min(max(volume / 100, 0), 1))
            }
            .frame(height: 4)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                onChange(max(0, min(1, g.location.x / geo.size.width)) * 100)
            })
        }
        .frame(height: 12)
    }
}
