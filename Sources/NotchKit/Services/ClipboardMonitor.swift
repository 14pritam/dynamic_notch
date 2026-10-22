import AppKit
import Observation

/// Watches the pasteboard for copied text. macOS has no change notification, so it checks the
/// change count a little more than once a second, which costs next to nothing. Copies marked
/// private (passwords) are skipped, and nothing is written to disk.
@MainActor
@Observable
public final class ClipboardMonitor {
    public private(set) var history = ClipboardHistory()
    /// The entry that was just copied back, for a moment of feedback on its card.
    public private(set) var justCopied: UUID?

    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private var lastChangeCount: Int
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        lastChangeCount = pasteboard.changeCount
    }

    public var isRunning: Bool { timer != nil }

    public func start() {
        guard timer == nil else { return }
        // Whatever was on the pasteboard before watching started isn't a new copy.
        lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Stops watching and forgets the history.
    public func stop() {
        timer?.invalidate()
        timer = nil
        history.removeAll()
    }

    public func check() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        let types = (pasteboard.types ?? []).map(\.rawValue)
        guard ClipboardRules.shouldRecord(types: types),
              let text = pasteboard.string(forType: .string) else { return }
        history.add(text, appName: NSWorkspace.shared.frontmostApplication?.localizedName)
    }

    /// Puts an entry back on the pasteboard so it can be pasted, and moves it to the front.
    public func copy(_ entry: ClipboardHistory.Entry) {
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
        // Our own copy is not a new entry; just move this one to the front.
        lastChangeCount = pasteboard.changeCount
        history.add(entry.text, appName: entry.appName)
        justCopied = history.entries.first?.id
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self?.justCopied = nil
        }
    }

    public func remove(_ id: UUID) {
        history.remove(id)
    }

    public func removeAll() {
        history.removeAll()
    }
}
