import Foundation

/// A stopwatch as a value with an injected clock, so it can be tested without waiting.
public struct Stopwatch: Equatable, Sendable {
    /// Time banked by earlier runs, before the current one started.
    public private(set) var banked: TimeInterval = 0
    /// When the current run started; nil while paused.
    public private(set) var runningSince: Date?

    public init() {}

    public var isRunning: Bool { runningSince != nil }

    public func elapsed(at now: Date) -> TimeInterval {
        banked + (runningSince.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    public mutating func start(now: Date) {
        guard runningSince == nil else { return }
        runningSince = now
    }

    public mutating func pause(now: Date) {
        guard let since = runningSince else { return }
        banked += max(0, now.timeIntervalSince(since))
        runningSince = nil
    }
}

/// What the Timer panel is set to start.
public enum TimerPanelMode: String, CaseIterable, Sendable {
    case timer
    case focus
    case stopwatch
}

/// The minutes the Timer panel's ruler offers.
public enum TimerRuler {
    public static let timerRange = 1...60
    public static let focusRange = 5...60
}
