import Foundation
import Observation

/// Watches the Downloads folder and reports each file once it has finished arriving. Browsers
/// write to a temporary name (.download, .crdownload, .part) and rename at the end, so a new
/// regular name whose size has stopped changing is a finished download.
@MainActor
public final class DownloadsWatcher {
    public var onFinished: ((URL) -> Void)?

    private let folder: URL
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []
    private var checkTask: Task<Void, Never>?

    public init(folder: URL? = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first) {
        self.folder = folder ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
    }

    public var isRunning: Bool { source != nil }

    public func start() {
        guard source == nil else { return }
        // Reading the folder is what asks for Downloads access, once.
        known = Set(names())
        let descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename], queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleCheck() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    public func stop() {
        source?.cancel()
        source = nil
        checkTask?.cancel()
        checkTask = nil
    }

    private func scheduleCheck() {
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.check()
        }
    }

    private func check() {
        let current = names()
        let fresh = current.filter { !known.contains($0) && DownloadRules.isFinishedName($0) }
        known = Set(current)
        var waiting = false
        for name in fresh {
            let url = folder.appendingPathComponent(name)
            if DownloadRules.isSettled(url) {
                onFinished?(url)
            } else {
                // Still being written: forget it and look again shortly.
                known.remove(name)
                waiting = true
            }
        }
        if waiting { scheduleCheck() }
    }

    private func names() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    }
}

public enum DownloadRules {
    static let partialExtensions: Set<String> = ["download", "crdownload", "part", "partial", "opdownload", "tmp"]

    /// A visible, non-temporary name.
    public static func isFinishedName(_ name: String) -> Bool {
        guard !name.hasPrefix("."), !name.isEmpty else { return false }
        return !partialExtensions.contains((name as NSString).pathExtension.lowercased())
    }

    /// Exists and wasn't modified in the last second.
    static func isSettled(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let modified = values.contentModificationDate else { return false }
        return Date().timeIntervalSince(modified) >= 1
    }
}
