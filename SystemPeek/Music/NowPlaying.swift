import AppKit

/// The currently playing track (from Apple Music or Spotify).
struct NowPlayingInfo: Equatable {
    var source: String      // "Music" or "Spotify"
    var title: String
    var artist: String
    var trackID: String     // for change detection
}

/// Reads now-playing state from Apple Music / Spotify. Text queries run via
/// `osascript` (call these off the main thread — the first call can block on the
/// Automation permission prompt). Only queries an app if it's already running.
enum NowPlaying {
    private static let stateScript = """
    set out to "none"
    tell application "System Events"
        set spotifyOn to (exists (processes whose bundle identifier is "com.spotify.client"))
        set musicOn to (exists (processes whose bundle identifier is "com.apple.Music"))
    end tell
    if spotifyOn then
        try
            tell application "Spotify"
                if player state is playing then
                    set out to "Spotify" & tab & (name of current track) & tab & (artist of current track)
                end if
            end tell
        end try
    end if
    if out is "none" and musicOn then
        try
            tell application "Music"
                if player state is playing then
                    set out to "Music" & tab & (name of current track) & tab & (artist of current track)
                end if
            end tell
        end try
    end if
    return out
    """

    /// Call off the main thread.
    static func current() -> NowPlayingInfo? {
        guard let result = osascript(stateScript), result != "none" else { return nil }
        let parts = result.components(separatedBy: "\t")
        guard parts.count >= 3 else { return nil }
        return NowPlayingInfo(source: parts[0], title: parts[1], artist: parts[2],
                              trackID: "\(parts[0])|\(parts[1])|\(parts[2])")
    }

    /// Spotify artwork URL (text). Call off the main thread.
    static func spotifyArtworkURL() -> URL? {
        guard let s = osascript("tell application \"Spotify\" to get artwork url of current track") else { return nil }
        return URL(string: s)
    }

    /// Apple Music artwork as image data. Uses NSAppleScript — call on the main thread.
    static func musicArtwork() -> NSImage? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source:
            "tell application \"Music\" to get data of artwork 1 of current track") else { return nil }
        let descriptor = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return NSImage(data: descriptor.data)
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
