import Foundation
import Observation

@MainActor
@Observable
public final class StopwatchService {
    public private(set) var stopwatch: Stopwatch?
    @ObservationIgnored private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    /// Running, or paused with time on it.
    public var isActive: Bool { stopwatch != nil }

    public func elapsed(at date: Date) -> TimeInterval {
        stopwatch?.elapsed(at: date) ?? 0
    }

    public func start() {
        var watch = stopwatch ?? Stopwatch()
        watch.start(now: now())
        stopwatch = watch
    }

    public func pause() {
        stopwatch?.pause(now: now())
    }

    public func togglePause() {
        guard let stopwatch else { return start() }
        if stopwatch.isRunning { pause() } else { start() }
    }

    public func reset() {
        stopwatch = nil
    }
}
