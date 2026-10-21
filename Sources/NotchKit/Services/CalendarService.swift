import AppKit
import EventKit
import Observation

/// A calendar event, copied out of EventKit so views and tests don't touch EKEvent.
public struct CalendarEvent: Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var start: Date
    public var end: Date
    public var color: ColorMath.RGB

    public init(id: String, title: String, start: Date, end: Date, color: ColorMath.RGB = .white) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.color = color
    }

    public func isHappening(at date: Date) -> Bool {
        start <= date && date < end
    }
}

/// Pure rules for which event to show and when to warn about it.
public enum CalendarRules {
    /// How long before an event starts the notch gives a heads-up.
    public static let reminderLead: TimeInterval = 5 * 60

    /// The event happening now, or else the next one to start.
    public static func nextEvent(in events: [CalendarEvent], at date: Date) -> CalendarEvent? {
        events
            .filter { $0.end > date }
            .sorted { $0.start < $1.start }
            .first
    }

    /// The next moment a heads-up is due, and for which event. Skips events already reminded.
    public static func nextReminder(in events: [CalendarEvent], after date: Date, reminded: Set<String>)
        -> (event: CalendarEvent, at: Date)? {
        events
            .filter { !reminded.contains($0.id) && $0.start > date }
            .map { (event: $0, at: max(date, $0.start.addingTimeInterval(-reminderLead))) }
            .min { $0.at < $1.at }
    }

    /// "now", "in 12 min", "in 1 hr", or a clock time for later today.
    public static func relativeLabel(for event: CalendarEvent, at date: Date) -> String {
        if event.isHappening(at: date) { return String(localized: "now") }
        let minutes = Int((event.start.timeIntervalSince(date) / 60).rounded(.up))
        if minutes < 60 { return String(localized: "in \(max(minutes, 1)) min") }
        if minutes < 120 { return String(localized: "in 1 hr") }
        return event.start.formatted(date: .omitted, time: .shortened)
    }
}

/// Reads the user's calendars (only after they allow it) for the Home tab and event heads-ups.
@MainActor
@Observable
public final class CalendarService {
    public enum Access: Equatable, Sendable {
        case notAsked
        case granted
        case denied
    }

    public private(set) var access: Access = .notAsked
    public private(set) var events: [CalendarEvent] = []

    /// Called when an event is about to start.
    @ObservationIgnored public var onReminder: ((CalendarEvent) -> Void)?

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var reminded = Set<String>()
    @ObservationIgnored private var reminderTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var isRunning = false

    public init() {
        access = Self.currentAccess()
    }

    public var nextEvent: CalendarEvent? {
        CalendarRules.nextEvent(in: events, at: Date())
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        access = Self.currentAccess()
        observers.append(NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        })
        reload()
    }

    public func stop() {
        isRunning = false
        observers.forEach { NotificationCenter.default.removeObserver($0); NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
        reminderTask?.cancel()
        refreshTask?.cancel()
    }

    /// Asks for calendar access. Only ever called from a button the user pressed.
    public func requestAccess() {
        Task { [weak self] in
            guard let self else { return }
            let granted = (try? await self.store.requestFullAccessToEvents()) ?? false
            self.access = granted ? .granted : .denied
            self.reload()
        }
    }

    public func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    public func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    private func reload() {
        access = Self.currentAccess()
        guard isRunning, access == .granted else {
            events = []
            scheduleReminder()
            return
        }
        let now = Date()
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-6 * 3600), end: now.addingTimeInterval(24 * 3600), calendars: nil)
        let fresh = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.status != .canceled && !Self.isDeclined($0) }
            .map { event in
                CalendarEvent(
                    id: (event.calendarItemIdentifier) + "@" + String(event.startDate.timeIntervalSince1970),
                    title: event.title?.isEmpty == false ? event.title! : String(localized: "Event"),
                    start: event.startDate,
                    end: event.endDate,
                    color: Self.rgb(event.calendar?.color)
                )
            }
            .sorted { $0.start < $1.start }
        if fresh != events {
            events = fresh
        }
        scheduleReminder()
        scheduleRefresh()
    }

    private static func isDeclined(_ event: EKEvent) -> Bool {
        event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }

    private static func rgb(_ color: NSColor?) -> ColorMath.RGB {
        guard let color = color?.usingColorSpace(.sRGB) else { return .white }
        return ColorMath.RGB(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }

    private func scheduleReminder() {
        reminderTask?.cancel()
        reminderTask = nil
        guard let next = CalendarRules.nextReminder(in: events, after: Date(), reminded: reminded) else { return }
        let delay = max(0, next.at.timeIntervalSinceNow)
        reminderTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay), tolerance: .seconds(1))
            guard !Task.isCancelled, let self else { return }
            self.reminded.insert(next.event.id)
            self.onReminder?(next.event)
            self.scheduleReminder()
        }
    }

    /// The "in 12 min" label and the next event roll over as time passes.
    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60), tolerance: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.reload()
        }
    }
}
