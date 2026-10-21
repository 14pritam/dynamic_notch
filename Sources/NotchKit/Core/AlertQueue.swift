import Foundation

/// Holds system alerts so they show one at a time, each for its own duration.
public struct AlertQueue: Equatable, Sendable {
    public private(set) var current: IslandAlert?
    public private(set) var shownAt: Date?
    public private(set) var pending: [IslandAlert] = []

    public init() {}

    /// Adds an alert. A newer alert of the same kind replaces the older one, whether it is
    /// showing or waiting. An urgent alert takes over from a non-urgent one, which goes back to
    /// the front of the line. Returns true if the visible alert changed.
    @discardableResult
    public mutating func enqueue(_ alert: IslandAlert, now: Date) -> Bool {
        if let current, current.kind == alert.kind {
            self.current = alert
            shownAt = now
            return true
        }
        pending.removeAll { $0.kind == alert.kind }
        if alert.isUrgent, let current, !current.isUrgent {
            pending.insert(current, at: 0)
            self.current = alert
            shownAt = now
            return true
        }
        pending.append(alert)
        return false
    }

    /// Shows the next waiting alert if nothing is showing. When `allowNonUrgent` is false
    /// (an expanded view is open) only urgent alerts may jump in.
    @discardableResult
    public mutating func promote(now: Date, allowNonUrgent: Bool) -> Bool {
        guard current == nil else { return false }
        guard let index = pending.firstIndex(where: { allowNonUrgent || $0.isUrgent }) else { return false }
        current = pending.remove(at: index)
        shownAt = now
        return true
    }

    /// When the visible alert should go away.
    public var expiry: Date? {
        guard let current, let shownAt else { return nil }
        return shownAt.addingTimeInterval(current.displayDuration)
    }

    /// Removes the visible alert if its time is up. Returns true if it was removed.
    @discardableResult
    public mutating func expire(now: Date) -> Bool {
        guard let expiry, now >= expiry else { return false }
        dismissCurrent()
        return true
    }

    public mutating func dismissCurrent() {
        current = nil
        shownAt = nil
    }

    /// Drops every alert of a kind, showing or waiting.
    public mutating func removeAll(of kind: IslandAlert.Kind) {
        pending.removeAll { $0.kind == kind }
        if current?.kind == kind {
            dismissCurrent()
        }
    }
}
