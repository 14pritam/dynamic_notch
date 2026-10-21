import AppKit
import Observation

/// What is playing anywhere on the Mac, plus play/pause/skip/seek.
@MainActor
@Observable
public final class NowPlayingService {
    public private(set) var info: NowPlayingInfo?
    public private(set) var artwork: NSImage?
    public private(set) var accent: ColorMath.RGB = .white
    public private(set) var appIcon: NSImage?
    public private(set) var appName: String?
    /// False when the helper can't run on this Mac.
    public private(set) var isAvailable = true
    /// True for a while after playback pauses, so the activity doesn't vanish instantly.
    public private(set) var isLingering = false

    public var lingerDuration: TimeInterval = 30

    /// Whether Now Playing should appear as a live activity.
    public var isActivityVisible: Bool {
        guard let info, info.hasContent else { return false }
        return info.isPlaying || isLingering
    }

    @ObservationIgnored private let bridge = MediaBridgeClient()
    @ObservationIgnored private var lingerTask: Task<Void, Never>?
    @ObservationIgnored private var resolvedBundleIdentifier: String?
    /// After play/pause from the pill, the state we expect the player to report. A helper update
    /// sent before the player reacted would otherwise flip the button back for a moment.
    @ObservationIgnored private var expectedPlayState: (isPlaying: Bool, until: Date)?
    /// Artwork we asked the helper to resend, so a missing image triggers one request, not a loop.
    @ObservationIgnored private var requestedArtworkKey: String?

    public init() {
        bridge.onMessage = { [weak self] message in self?.handle(message) }
        bridge.onStateChange = { [weak self] state in
            self?.isAvailable = state != .unavailable
            if state == .unavailable {
                self?.apply(nil, artworkData: nil)
            }
        }
    }

    public func start() {
        bridge.start()
    }

    public func stop() {
        bridge.stop()
        lingerTask?.cancel()
    }

    // MARK: Controls

    public func togglePlayPause() {
        guard var current = info else { return }
        let now = Date()
        current.elapsed = current.elapsed(at: now)
        current.sampledAt = now
        current.isPlaying.toggle()
        expectedPlayState = (current.isPlaying, now.addingTimeInterval(1.5))
        applyLocally(current)
        bridge.send("toggle")
    }

    public func nextTrack() {
        bridge.send("next")
    }

    public func previousTrack() {
        bridge.send("previous")
    }

    public func seek(to seconds: TimeInterval) {
        guard var current = info, let duration = current.duration else { return }
        let target = min(max(seconds, 0), duration)
        current.elapsed = target
        current.sampledAt = Date()
        applyLocally(current)
        bridge.send("seek \(target)")
    }

    public func openSourceApp() {
        if let pid = info?.processIdentifier, let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular {
            app.activate()
            return
        }
        guard
            let identifier = resolvedBundleIdentifier,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
        else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Updates

    func handle(_ parsed: ParsedBridgeMessage) {
        switch parsed.message {
        case .ready:
            isAvailable = true
        case .error:
            break
        case .nowPlaying(let newInfo, let artworkData):
            apply(newInfo, artworkData: artworkData, accent: parsed.artworkAccent)
        }
    }

    func apply(_ newInfo: NowPlayingInfo?, artworkData: Data?, accent newAccent: ColorMath.RGB? = nil, now: Date = Date()) {
        guard var newInfo else {
            info = nil
            artwork = nil
            accent = .white
            appIcon = nil
            appName = nil
            resolvedBundleIdentifier = nil
            endLinger()
            return
        }

        if let expected = expectedPlayState {
            if now >= expected.until || newInfo.isPlaying == expected.isPlaying {
                expectedPlayState = nil
            } else if let local = info, local.title == newInfo.title {
                // Stale report from before the player reacted: keep the local playback state.
                newInfo.isPlaying = local.isPlaying
                newInfo.elapsed = local.elapsed
                newInfo.sampledAt = local.sampledAt
                newInfo.playbackRate = local.playbackRate
            }
        }

        updateArtwork(for: newInfo, data: artworkData, accent: newAccent)
        updateSourceApp(for: newInfo)

        let wasPlaying = info?.isPlaying ?? false
        info = newInfo
        if newInfo.isPlaying {
            endLinger()
        } else if wasPlaying {
            beginLinger()
        }
    }

    private func applyLocally(_ updated: NowPlayingInfo) {
        let wasPlaying = info?.isPlaying ?? false
        info = updated
        if updated.isPlaying {
            endLinger()
        } else if wasPlaying {
            beginLinger()
        }
    }

    private func updateArtwork(for newInfo: NowPlayingInfo, data: Data?, accent newAccent: ColorMath.RGB?) {
        if let data, let image = NSImage(data: data) {
            artwork = image
            accent = newAccent ?? ArtworkTint.accent(of: data)
            return
        }
        // No new bytes: keep the current image only if it belongs to this track.
        if newInfo.artworkKey == nil || newInfo.artworkKey != info?.artworkKey || artwork == nil {
            artwork = nil
            accent = .white
            // The track has art we never received (for example after a helper restart): ask once.
            if let key = newInfo.artworkKey, key != requestedArtworkKey {
                requestedArtworkKey = key
                bridge.send("refresh")
            }
        }
    }

    private func updateSourceApp(for newInfo: NowPlayingInfo) {
        var identifier = newInfo.bundleIdentifier
        if let pid = newInfo.processIdentifier, let app = NSRunningApplication(processIdentifier: pid) {
            if identifier == nil || app.activationPolicy == .regular {
                identifier = app.bundleIdentifier ?? identifier
            }
        }
        guard identifier != resolvedBundleIdentifier else { return }
        resolvedBundleIdentifier = identifier
        guard let identifier, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else {
            appIcon = nil
            appName = nil
            return
        }
        appIcon = NSWorkspace.shared.icon(forFile: url.path)
        appName = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func beginLinger() {
        lingerTask?.cancel()
        isLingering = true
        let duration = lingerDuration
        lingerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.isLingering = false
        }
    }

    private func endLinger() {
        lingerTask?.cancel()
        lingerTask = nil
        isLingering = false
    }
}
