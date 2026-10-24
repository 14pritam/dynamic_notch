import Foundation
import Testing
@testable import NotchKit

private func tempFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("NotchTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

@MainActor
@Suite("File Tray")
struct TrayTests {
    @Test func addsRealFilesOnceNewestFirst() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let a = folder.appendingPathComponent("a.txt")
        let b = folder.appendingPathComponent("b.txt")
        try Data("a".utf8).write(to: a)
        try Data("b".utf8).write(to: b)
        let tray = TrayStore(folder: nil)
        #expect(tray.add([a]) == 1)
        #expect(tray.add([b, a, folder.appendingPathComponent("missing.txt"), URL(string: "https://example.com")!]) == 1)
        #expect(tray.items.map(\.name) == ["b.txt", "a.txt"])
    }

    @Test func survivesRelaunchAndForgetsDeletedFiles() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = folder.appendingPathComponent("store", isDirectory: true)
        let keep = folder.appendingPathComponent("keep.pdf")
        let gone = folder.appendingPathComponent("gone.pdf")
        try Data().write(to: keep)
        try Data().write(to: gone)
        TrayStore(folder: store).add([keep, gone])
        try FileManager.default.removeItem(at: gone)
        let reloaded = TrayStore(folder: store)
        #expect(reloaded.items.map(\.name) == ["keep.pdf"])
    }

    @Test func removeAndClear() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = try (0..<3).map { index -> URL in
            let url = folder.appendingPathComponent("\(index).txt")
            try Data().write(to: url)
            return url
        }
        let tray = TrayStore(folder: nil)
        tray.add(files)
        tray.remove(tray.items[0].id)
        #expect(tray.items.count == 2)
        tray.removeAll()
        #expect(tray.items.isEmpty)
    }

    @Test func pruneDropsMovedFiles() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("x.txt")
        try Data().write(to: file)
        let tray = TrayStore(folder: nil)
        tray.add([file])
        try FileManager.default.removeItem(at: file)
        tray.pruneMissing()
        #expect(tray.items.isEmpty)
    }

    @Test func capacityKeepsTheNewest() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let files = try (0..<(TrayStore.capacity + 5)).map { index -> URL in
            let url = folder.appendingPathComponent("\(index).txt")
            try Data().write(to: url)
            return url
        }
        let tray = TrayStore(folder: nil)
        for file in files { tray.add([file]) }
        #expect(tray.items.count == TrayStore.capacity)
        #expect(tray.items.first?.name == "\(TrayStore.capacity + 4).txt")
    }
}

@Suite("Calendar rules")
struct CalendarRuleTests {
    let now = Date(timeIntervalSince1970: 1_000_000)

    private func event(_ id: String, startsIn minutes: Double, lasts: Double = 30) -> CalendarEvent {
        let start = now.addingTimeInterval(minutes * 60)
        return CalendarEvent(id: id, title: id, start: start, end: start.addingTimeInterval(lasts * 60))
    }

    @Test func nextEventPrefersWhatIsHappeningNow() {
        let events = [event("later", startsIn: 60), event("now", startsIn: -10), event("over", startsIn: -90)]
        #expect(CalendarRules.nextEvent(in: events, at: now)?.id == "now")
        #expect(CalendarRules.nextEvent(in: [event("over", startsIn: -90)], at: now) == nil)
    }

    @Test func reminderFiveMinutesBeforeAndOnlyOnce() throws {
        let events = [event("a", startsIn: 20), event("b", startsIn: 3)]
        let first = try #require(CalendarRules.nextReminder(in: events, after: now, reminded: []))
        #expect(first.event.id == "b")
        #expect(first.at == now, "already inside the 5-minute window: remind right away")
        let second = try #require(CalendarRules.nextReminder(in: events, after: now, reminded: ["b"]))
        #expect(second.event.id == "a")
        #expect(second.at == now.addingTimeInterval(15 * 60))
        #expect(CalendarRules.nextReminder(in: events, after: now, reminded: ["a", "b"]) == nil)
        #expect(CalendarRules.nextReminder(in: [event("started", startsIn: -1)], after: now, reminded: []) == nil)
    }

    @Test func labels() {
        #expect(CalendarRules.relativeLabel(for: event("x", startsIn: -5), at: now) == "now")
        #expect(CalendarRules.relativeLabel(for: event("x", startsIn: 12), at: now) == "in 12 min")
        #expect(CalendarRules.relativeLabel(for: event("x", startsIn: 0.2), at: now) == "in 1 min")
        #expect(CalendarRules.relativeLabel(for: event("x", startsIn: 75), at: now) == "in 1 hr")
    }
}

@Suite("Home and alerts for new features")
struct NewFeatureLayoutTests {
    let engine = LayoutEngine(screen: .sample, appearance: .standard)

    @Test func nookIsWideShortAndTheSameForEveryTab() throws {
        let notch = try #require(ScreenMetrics.sample.notch)
        let full = HomeContent(hasMedia: true, hasEvent: true, hasTimer: true, hasShortcuts: true)
        #expect(full.fitsInNook, "three widget rows fit beside the media card")
        let sizes = [IslandPresentation.home, .tray, .mirror].map { engine.layout(for: $0, home: full, hovering: false).pill.size }
        #expect(Set(sizes.map { "\($0)" }).count == 1, "switching tabs never resizes the shape")
        let home = engine.layout(for: .home, home: full, hovering: false)
        #expect(home.pill.width > home.pill.height * 2.5, "wide, not tall")
        #expect(home.pill.height <= notch.height + IslandMetrics.Nook.body + 30)
        #expect(home.stripHeight == notch.height, "tabs sit beside the camera")
        #expect(home.cameraGap == notch.width)
        #expect(home.content.minY == 0)
        let empty = engine.layout(for: .home, home: HomeContent(hasTimer: false), hovering: false)
        #expect(empty.pill == home.pill)
    }

    @Test func floatingPillKeepsTheHeaderInside() {
        var appearance = NotchAppearance.standard
        appearance.style = .island
        let layout = LayoutEngine(screen: .sample, appearance: appearance).layout(for: .home, home: HomeContent(), hovering: false)
        #expect(layout.stripHeight == 0)
        #expect(layout.content.height == IslandMetrics.ContentHeight.nook)
    }

    @Test func everyTabFitsTheWindow() {
        let bounds = CGRect(origin: .zero, size: engine.windowSize)
        let full = HomeContent(hasMedia: true, hasEvent: true, hasTimer: true, hasShortcuts: true)
        for presentation in [IslandPresentation.home, .tray, .mirror] {
            for style in NotchStyle.allCases {
                var appearance = NotchAppearance.standard
                appearance.style = style
                appearance.verticalOffset = NotchAppearance.verticalOffsetRange.upperBound
                let engine = LayoutEngine(screen: .sample, appearance: appearance)
                let layout = engine.layout(for: presentation, home: full, hovering: false)
                #expect(bounds.contains(layout.pill), "\(style) \(presentation)")
            }
        }
    }

    @Test func volumeIndicatorIsSlimmerThanOtherAlerts() {
        let level = engine.layout(for: .alert(.level(.volume, value: 0.5, muted: false)), home: HomeContent(), hovering: false)
        let charging = engine.layout(for: .alert(.charging(level: 50, isCharging: true)), home: HomeContent(), hovering: false)
        #expect(level.pill.width < charging.pill.width)
        #expect(level.pill.height < charging.pill.height)
    }

    @Test func tabsResolve() {
        #expect(PresentationResolver.resolve(PresentationInput(expandTarget: .tray)) == .tray)
        #expect(PresentationResolver.resolve(PresentationInput(expandTarget: .mirror)) == .mirror)
        #expect(IslandPresentation.tray.isExpandedFamily && IslandPresentation.mirror.isExpandedFamily)
        #expect(IslandPresentation.tray.homeTab == .tray)
        #expect(ExpandTarget(.mirror) == .mirror)
    }

    @Test func levelIsInstantAndNeverReplayed() {
        let start = Date()
        var queue = AlertQueue()
        queue.enqueue(.charging(level: 50, isCharging: true), now: start)
        queue.promote(now: start, allowNonUrgent: true)
        let volume = IslandAlert.level(.volume, value: 0.4, muted: false)
        let shown = queue.enqueue(volume, now: start)
        #expect(shown)
        #expect(queue.current == volume)
        #expect(queue.pending == [.charging(level: 50, isCharging: true)])
        // Pressing again updates in place.
        let updated = queue.enqueue(.level(.volume, value: 0.5, muted: false), now: start)
        #expect(updated)
        #expect(queue.pending.count == 1)
        // Timer done takes over and the stale level is dropped.
        queue.enqueue(.timerFinished, now: start)
        #expect(queue.current == .timerFinished)
        #expect(!queue.pending.contains { $0.kind == .level })
        // Volume while timer done shows is ignored.
        let ignored = queue.enqueue(volume, now: start)
        #expect(!ignored)
        #expect(!queue.pending.contains { $0.kind == .level })
    }

    @Test func brightnessHeuristic() {
        #expect(LevelMonitor.isUserBrightnessChange(from: 0.5, to: 0.5625))
        #expect(!LevelMonitor.isUserBrightnessChange(from: 0.5, to: 0.51))
        #expect(LevelMonitor.isUserBrightnessChange(from: 0.02, to: 0))
        #expect(LevelMonitor.isUserBrightnessChange(from: 0.98, to: 1))
    }
}

@MainActor
@Suite("Model: tray, tabs and drops")
struct NewFeatureModelTests {
    private func makeModel() -> IslandModel {
        let defaults = UserDefaults(suiteName: "NewFeatureModelTests.\(UUID().uuidString)")!
        let model = IslandModel(settings: SettingsStore(defaults: defaults), tray: TrayStore(folder: nil))
        model.screen = .sample
        return model
    }

    @Test func droppingIntoTheTrayShowsIt() throws {
        let folder = try tempFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("doc.txt")
        try Data().write(to: file)
        let model = makeModel()
        let zone = model.engine.dropZone
        model.fileDragChanged(isDragging: true, at: CGPoint(x: zone.midX, y: 5))
        model.setTargeted(.tray, true)
        #expect(model.targetedZone == .tray)
        #expect(model.presentation == .drop(targeted: true))
        model.addToTray([file])
        #expect(model.presentation == .tray)
        #expect(model.tray.items.count == 1)
    }

    @Test func draggingOutOfTheTrayIsNotANewDrop() {
        let model = makeModel()
        model.showTab(.tray)
        model.isDraggingFromTray = true
        model.fileDragChanged(isDragging: true, at: CGPoint(x: model.engine.dropZone.midX, y: 5))
        #expect(model.presentation == .tray)
        model.fileDragChanged(isDragging: false, at: nil)
        #expect(!model.isDraggingFromTray)
    }

    @Test func dropsNeedADestination() {
        let model = makeModel()
        model.settings.airDropEnabled = false
        model.settings.trayEnabled = false
        model.fileDragChanged(isDragging: true, at: CGPoint(x: model.engine.dropZone.midX, y: 5))
        #expect(model.presentation == .hidden(peek: false))
    }

    @Test func tabsFollowSettings() {
        let model = makeModel()
        #expect(model.homeTabs == [.home, .tray, .clipboard])
        model.settings.mirrorEnabled = false
        model.settings.clipboardEnabled = false
        model.settings.notesEnabled = false
        #expect(model.homeTabs == [.home, .tray])
    }

    @Test func homeRowsFollowSettings() {
        let model = makeModel()
        model.settings.calendarEnabled = false
        #expect(!model.homeContent.hasEvent)
        model.settings.favoriteShortcuts = ["A"]
        #expect(model.homeContent.hasShortcuts)
        model.settings.shortcutsEnabled = false
        #expect(!model.homeContent.hasShortcuts)
        model.settings.timerEnabled = false
        #expect(!model.homeContent.hasTimer)
    }

    @Test func levelsStayOutOfExpandedViews() {
        let model = makeModel()
        model.levels.onChange?(.volume, 0.3, false)
        #expect(model.presentation == .alert(.level(.volume, value: 0.3, muted: false)))
        model.dismissAlert()
        model.expand(.home)
        model.levels.onChange?(.volume, 0.4, false)
        #expect(model.presentation == .home)
        model.collapse()
        model.settings.levelsEnabled = false
        model.levels.onChange?(.volume, 0.5, false)
        #expect(model.presentation == .hidden(peek: false))
    }

    @Test func favouritesAreCapped() {
        let defaults = UserDefaults(suiteName: "fav.\(UUID().uuidString)")!
        let store = SettingsStore(defaults: defaults)
        for name in ["A", "B", "C", "D"] { #expect(store.toggleFavorite(name)) }
        #expect(!store.toggleFavorite("E"))
        #expect(store.toggleFavorite("B"))
        #expect(store.favoriteShortcuts == ["A", "C", "D"])
        #expect(SettingsStore(defaults: defaults).favoriteShortcuts == ["A", "C", "D"])
    }
}
