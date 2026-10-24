import AppKit
import CryptoKit
import Observation
import os

/// Keeps the app up to date from its GitHub releases. Once a day (when allowed in Settings) it asks
/// GitHub for the latest release; that request is the only time the app goes online. Installing
/// downloads the disk image, checks it against the SHA-256 published with it, swaps the app in
/// place and reopens it.
@MainActor
@Observable
public final class Updater {
    public enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case installing
        case failed(String)
    }

    public private(set) var state: State = .idle
    /// Called once per new version found by an automatic check.
    @ObservationIgnored public var onAvailable: ((ReleaseInfo) -> Void)?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let log = Logger(subsystem: Log.subsystem, category: "updates")

    public static let latestRelease = URL(string: "https://api.github.com/repos/shandilyaswagat/dynamic_notch/releases/latest")!
    static let checkInterval: TimeInterval = 24 * 3600

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var currentVersion: SemanticVersion? {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(SemanticVersion.init)
    }

    public var availableRelease: ReleaseInfo? {
        if case .available(let release) = state { return release }
        return nil
    }

    /// Checks now if a day has passed, then looks again every few hours.
    public func startAutomaticChecks() {
        guard timer == nil else { return }
        checkIfDue()
        let timer = Timer(timeInterval: 3 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIfDue() }
        }
        timer.tolerance = 600
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stopAutomaticChecks() {
        timer?.invalidate()
        timer = nil
    }

    private func checkIfDue() {
        let last = defaults.object(forKey: Key.lastCheck) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) >= Self.checkInterval else { return }
        check(userInitiated: false)
    }

    public func check(userInitiated: Bool = true) {
        if case .installing = state { return }
        state = .checking
        Task { [weak self] in
            guard let self else { return }
            do {
                var request = URLRequest(url: Self.latestRelease, timeoutInterval: 20)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200, let release = ReleaseInfo.parse(data) else {
                    throw UpdateError.unreadable
                }
                self.defaults.set(Date(), forKey: Key.lastCheck)
                if let current = self.currentVersion, release.version > current {
                    self.state = .available(release)
                    let announced = self.defaults.string(forKey: Key.announced)
                    if !userInitiated, announced != release.version.description {
                        self.defaults.set(release.version.description, forKey: Key.announced)
                        self.onAvailable?(release)
                    }
                } else {
                    self.state = .upToDate
                }
            } catch {
                self.log.notice("Update check failed: \(error.localizedDescription, privacy: .public)")
                self.state = userInitiated ? .failed(String(localized: "Couldn't reach GitHub. Try again later.")) : .idle
            }
        }
    }

    /// Downloads, verifies and installs the release, then relaunches. Opens the release page
    /// instead when the app can't replace itself (read-only location, or run from a disk image).
    public func install(_ release: ReleaseInfo) {
        let destination = Bundle.main.bundleURL
        guard Self.canReplace(destination), release.checksum != nil else {
            NSWorkspace.shared.open(release.page)
            return
        }
        state = .installing
        Task { [weak self] in
            guard let self else { return }
            do {
                let staged = try await Self.download(release)
                try Self.relaunch(replacing: destination, with: staged)
            } catch {
                self.log.error("Update failed: \(error.localizedDescription, privacy: .public)")
                self.state = .failed(String(localized: "The update couldn't be installed. You can download it from GitHub instead."))
            }
        }
    }

    // MARK: Steps

    enum UpdateError: Error {
        case unreadable
        case checksumMismatch
        case noApp
    }

    nonisolated static func canReplace(_ app: URL) -> Bool {
        let path = app.path
        // Translocated or mounted copies can't be swapped in place.
        guard !path.contains("/AppTranslocation/"), !path.hasPrefix("/Volumes/") else { return false }
        return FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path)
    }

    /// Downloads and verifies the disk image, then copies the app out of it into a staging folder.
    nonisolated static func download(_ release: ReleaseInfo) async throws -> URL {
        guard let checksumURL = release.checksum else { throw UpdateError.unreadable }
        let (checksumData, _) = try await URLSession.shared.data(from: checksumURL)
        let expected = String(decoding: checksumData, as: UTF8.self)
            .split(whereSeparator: \.isWhitespace).first.map { $0.lowercased() } ?? ""
        let (file, _) = try await URLSession.shared.download(from: release.diskImage)
        let image = try Data(contentsOf: file, options: .mappedIfSafe)
        let actual = SHA256.hash(data: image).map { String(format: "%02x", $0) }.joined()
        guard !expected.isEmpty, actual == expected else { throw UpdateError.checksumMismatch }

        let work = FileManager.default.temporaryDirectory.appendingPathComponent("DynamicNotchUpdate-\(UUID().uuidString)")
        let mount = work.appendingPathComponent("mount")
        let staged = work.appendingPathComponent("staged")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: staged, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", ["attach", file.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path])
        defer { _ = try? run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }
        guard let app = try FileManager.default.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else { throw UpdateError.noApp }
        let copy = staged.appendingPathComponent(app.lastPathComponent)
        try run("/usr/bin/ditto", [app.path, copy.path])
        return copy
    }

    /// Hands over to a small script that waits for this app to quit, swaps the bundle and reopens it.
    static func relaunch(replacing destination: URL, with staged: URL) throws {
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        rm -rf "$2.old" && mv "$2" "$2.old" && /usr/bin/ditto "$3" "$2" && rm -rf "$2.old" || { rm -rf "$2"; mv "$2.old" "$2"; }
        /usr/bin/xattr -dr com.apple.quarantine "$2" 2>/dev/null
        /usr/bin/open "$2"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", String(ProcessInfo.processInfo.processIdentifier), destination.path, staged.path]
        try process.run()
        NSApp.terminate(nil)
    }

    @discardableResult
    nonisolated static func run(_ tool: String, _ arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.unreadable }
        return process.terminationStatus
    }

    private enum Key {
        static let lastCheck = "updates.lastCheck"
        static let announced = "updates.announced"
    }
}
