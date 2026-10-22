import Foundation
import Observation

/// One plain-text scratchpad, saved as you type and kept across launches.
@MainActor
@Observable
public final class NotesStore {
    public var text: String {
        didSet {
            guard text != oldValue else { return }
            scheduleSave()
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    private static let key = "notes.text"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        text = defaults.string(forKey: Self.key) ?? ""
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Writes now instead of waiting for typing to pause (on quit, or when the notch closes).
    public func save() {
        saveTask?.cancel()
        saveTask = nil
        defaults.set(text, forKey: Self.key)
    }

    public func clear() {
        text = ""
        save()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }
}
