import AppKit

enum RepeatMode: String { case off, one, all }

/// Full now-playing state for the active player (Apple Music or Spotify).
struct NowPlayingInfo: Equatable {
    var source: String          // "Music" or "Spotify"
    var title: String
    var artist: String
    var album: String
    var trackID: String         // for artwork-change detection
    var duration: Double        // seconds
    var position: Double        // seconds
    var isPlaying: Bool
    var volume: Double          // 0...100
    var shuffle: Bool
    var repeatMode: RepeatMode
}

/// Reads/controls Apple Music & Spotify via AppleScript. Reads run via `osascript`
/// (call off the main thread). Only touches an app that's already running.
enum NowPlaying {
    private static let stateScript = """
    set tab to (ASCII character 9)
    set out to "none"
    tell application "System Events"
        set spOn to (exists (processes whose bundle identifier is "com.spotify.client"))
        set muOn to (exists (processes whose bundle identifier is "com.apple.Music"))
    end tell
    if spOn then
        try
            tell application "Spotify"
                if player state is not stopped then
                    set ct to current track
                    set out to "Spotify" & tab & (player state as string) & tab & (name of ct) & tab & (artist of ct) & tab & (album of ct) & tab & ((duration of ct) / 1000) & tab & (player position) & tab & (sound volume) & tab & (shuffling as string) & tab & (repeating as string)
                end if
            end tell
        end try
    end if
    if out is "none" and muOn then
        try
            tell application "Music"
                if player state is not stopped then
                    set rp to "off"
                    try
                        if (song repeat as string) is "one" then set rp to "one"
                        if (song repeat as string) is "all" then set rp to "all"
                    end try
                    set ct to current track
                    set out to "Music" & tab & (player state as string) & tab & (name of ct) & tab & (artist of ct) & tab & (album of ct) & tab & (duration of ct) & tab & (player position) & tab & (sound volume) & tab & (shuffle enabled as string) & tab & rp
                end if
            end tell
        end try
    end if
    return out
    """

    /// Call off the main thread.
    static func current() -> NowPlayingInfo? {
        guard let result = osascript(stateScript), result != "none" else { return nil }
        let f = result.components(separatedBy: "\t")
        guard f.count >= 10 else { return nil }
        let repeatMode: RepeatMode
        switch f[9].lowercased() {
        case "true", "all": repeatMode = .all
        case "one": repeatMode = .one
        default: repeatMode = .off
        }
        return NowPlayingInfo(
            source: f[0],
            title: f[2], artist: f[3], album: f[4],
            trackID: "\(f[0])|\(f[2])|\(f[3])",
            duration: Double(f[5]) ?? 0,
            position: Double(f[6]) ?? 0,
            isPlaying: f[1] == "playing",
            volume: Double(f[7]) ?? 50,
            shuffle: f[8] == "true",
            repeatMode: repeatMode
        )
    }

    static func spotifyArtworkURL() -> URL? {
        guard let s = osascript("tell application \"Spotify\" to get artwork url of current track") else { return nil }
        return URL(string: s)
    }

    /// NSAppleScript — call on the main thread.
    static func musicArtwork() -> NSImage? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source:
            "tell application \"Music\" to get data of artwork 1 of current track") else { return nil }
        let descriptor = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return NSImage(data: descriptor.data)
    }

    // MARK: - Controls (call off the main thread)

    static func playPause(_ source: String) { command(source, "playpause") }
    static func next(_ source: String) { command(source, "next track") }
    static func previous(_ source: String) { command(source, "previous track") }
    static func setVolume(_ source: String, _ value: Double) {
        command(source, "set sound volume to \(Int(value.rounded()))")
    }
    static func seek(_ source: String, _ seconds: Double) {
        command(source, "set player position to \(max(0, seconds))")
    }
    static func setShuffle(_ source: String, _ on: Bool) {
        let prop = source == "Spotify" ? "shuffling" : "shuffle enabled"
        command(source, "set \(prop) to \(on)")
    }
    static func setRepeat(_ source: String, _ mode: RepeatMode) {
        if source == "Spotify" {
            command(source, "set repeating to \(mode == .off ? "false" : "true")")
        } else {
            command(source, "set song repeat to \(mode.rawValue)")
        }
    }

    private static func command(_ source: String, _ cmd: String) {
        _ = osascript("tell application \"\(source)\" to \(cmd)")
    }

    private static func osascript(_ script: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (text?.isEmpty == false) ? text : nil
    }
}
