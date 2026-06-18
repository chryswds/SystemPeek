import AppKit
import Combine

/// Polls full playback state on a background queue and publishes it on the main
/// thread; also exposes transport controls.
final class NowPlayingMonitor: ObservableObject {
    @Published private(set) var info: NowPlayingInfo?
    @Published private(set) var artwork: NSImage?

    /// True while there's an active track (playing or paused).
    var hasTrack: Bool { info != nil }
    /// True while actually playing (drives the pulse animation).
    var isPlaying: Bool { info?.isPlaying ?? false }

    private var timer: Timer?
    private let queue = DispatchQueue(label: "com.chrys.SystemPeek.nowplaying")
    private var lastTrackID: String?

    func start() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
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
            DispatchQueue.main.async { [weak self] in self?.artwork = NowPlaying.musicArtwork() }
        }
    }

    // MARK: - Controls

    private func source() -> String? { info?.source }

    private func control(_ action: @escaping (String) -> Void) {
        guard let source = source() else { return }
        queue.async { [weak self] in
            action(source)
            self?.pollOnQueue()   // refresh after the change
        }
    }

    func togglePlayPause() {
        if var info { info.isPlaying.toggle(); self.info = info }   // optimistic
        control { NowPlaying.playPause($0) }
    }

    func next() { control { NowPlaying.next($0) } }
    func previous() { control { NowPlaying.previous($0) } }

    func setVolume(_ value: Double) {
        if var info { info.volume = value; self.info = info }       // optimistic (smooth slider)
        control { NowPlaying.setVolume($0, value) }
    }

    func seek(to seconds: Double) {
        if var info { info.position = seconds; self.info = info }    // optimistic
        control { NowPlaying.seek($0, seconds) }
    }

    func toggleShuffle() {
        let on = !(info?.shuffle ?? false)
        if var info { info.shuffle = on; self.info = info }
        control { NowPlaying.setShuffle($0, on) }
    }

    func cycleRepeat() {
        guard let info else { return }
        let next: RepeatMode
        if info.source == "Spotify" {
            next = info.repeatMode == .off ? .all : .off
        } else {
            switch info.repeatMode {
            case .off: next = .all
            case .all: next = .one
            case .one: next = .off
            }
        }
        self.info?.repeatMode = next
        control { NowPlaying.setRepeat($0, next) }
    }

    deinit { timer?.invalidate() }
}
