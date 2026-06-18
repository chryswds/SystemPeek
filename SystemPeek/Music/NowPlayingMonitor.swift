import AppKit
import Combine

/// Polls now-playing state on a background queue (so the Automation prompt and
/// AppleScript round-trips never block the UI) and publishes the track + artwork
/// on the main thread.
final class NowPlayingMonitor: ObservableObject {
    @Published private(set) var info: NowPlayingInfo?
    @Published private(set) var artwork: NSImage?

    var isPlaying: Bool { info != nil }

    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.chrys.SystemPeek.nowplaying")
    private var lastTrackID: String?   // only touched on `queue`

    func start() {
        let timer = Timer(timeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.queue.async { self?.pollOnQueue() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        queue.async { [weak self] in self?.pollOnQueue() }
    }

    private func pollOnQueue() {
        let current = NowPlaying.current()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if current != self.info { self.info = current }
            if current == nil, self.artwork != nil { self.artwork = nil }
        }
        if current?.trackID != lastTrackID {
            lastTrackID = current?.trackID
            if let current { fetchArtwork(for: current) }
        }
    }

    private func fetchArtwork(for info: NowPlayingInfo) {
        if info.source == "Spotify" {
            let image = NowPlaying.spotifyArtworkURL()
                .flatMap { try? Data(contentsOf: $0) }
                .flatMap { NSImage(data: $0) }
            DispatchQueue.main.async { [weak self] in self?.artwork = image }
        } else {
            // Apple Music artwork uses NSAppleScript, which must run on the main thread.
            DispatchQueue.main.async { [weak self] in self?.artwork = NowPlaying.musicArtwork() }
        }
    }

    deinit { timer?.invalidate() }
}
