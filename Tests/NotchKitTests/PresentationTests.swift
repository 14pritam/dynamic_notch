import Testing
@testable import NotchKit

@Suite("Presentation rules")
struct PresentationTests {
    @Test func hiddenWhenNothingIsHappening() {
        #expect(PresentationResolver.resolve(PresentationInput()) == .hidden(peek: false))
    }

    @Test func notchHoverPeeksOnlyWhenHidden() {
        #expect(PresentationResolver.resolve(PresentationInput(isHoveringNotch: true)) == .hidden(peek: true))
        let busy = PresentationInput(activeActivities: [.timer], isHoveringNotch: true)
        #expect(PresentationResolver.resolve(busy) == .compact(primary: .timer, secondary: nil))
    }

    @Test func idleWhenAskedOrPreviewing() {
        #expect(PresentationResolver.resolve(PresentationInput(showWhenIdle: true)) == .idle)
        #expect(PresentationResolver.resolve(PresentationInput(isPreviewing: true)) == .idle)
    }

    @Test func priorityIsCallThenTimerThenMusic() {
        let input = PresentationInput(activeActivities: [.nowPlaying, .timer, .call])
        #expect(PresentationResolver.resolve(input) == .compact(primary: .call, secondary: .timer))
        let two = PresentationInput(activeActivities: [.nowPlaying, .timer])
        #expect(PresentationResolver.resolve(two) == .compact(primary: .timer, secondary: .nowPlaying))
    }

    @Test func swipeChoiceWinsWhileActive() {
        let input = PresentationInput(activeActivities: [.nowPlaying, .timer], preferredPrimary: .nowPlaying)
        #expect(PresentationResolver.resolve(input) == .compact(primary: .nowPlaying, secondary: .timer))
        let stale = PresentationInput(activeActivities: [.timer], preferredPrimary: .nowPlaying)
        #expect(PresentationResolver.resolve(stale) == .compact(primary: .timer, secondary: nil))
    }

    @Test func swipingVisitsEveryActivity() {
        let all: Set<ActivityKind> = [.call, .timer, .nowPlaying]
        var current: ActivityKind? = .call
        var seen: [ActivityKind] = []
        for _ in 0..<3 {
            current = PresentationResolver.nextPrimary(all, current: current, forward: true)
            seen.append(current!)
        }
        #expect(seen == [.timer, .nowPlaying, .call])
        #expect(PresentationResolver.nextPrimary(all, current: .call, forward: false) == .nowPlaying)
        #expect(PresentationResolver.nextPrimary([.timer], current: .timer, forward: true) == nil)
        #expect(PresentationResolver.nextPrimary([.timer, .nowPlaying], current: nil, forward: true) == .nowPlaying)
    }

    @Test func expandedOnlyForActiveActivities() {
        let valid = PresentationInput(activeActivities: [.timer], expandTarget: .activity(.timer))
        #expect(PresentationResolver.resolve(valid) == .expanded(.timer))
        let ended = PresentationInput(activeActivities: [], expandTarget: .activity(.timer))
        #expect(PresentationResolver.resolve(ended) == .hidden(peek: false))
        #expect(PresentationResolver.resolve(PresentationInput(expandTarget: .home)) == .home)
    }

    @Test func alertsBeatExpandedAndDragBeatsAlerts() {
        let alert = PresentationInput(activeActivities: [.timer], alert: .lowBattery(level: 10), expandTarget: .home)
        #expect(PresentationResolver.resolve(alert) == .alert(.lowBattery(level: 10)))
        var drag = alert
        drag.isFileDragNear = true
        #expect(PresentationResolver.resolve(drag) == .drop(targeted: false))
        drag.isDropTargeted = true
        #expect(PresentationResolver.resolve(drag) == .drop(targeted: true))
    }

    @Test func topologyChangesOnlyOnShapeChanges() {
        let compact = IslandPresentation.compact(primary: .timer, secondary: nil)
        let other = IslandPresentation.compact(primary: .nowPlaying, secondary: nil)
        #expect(compact.topology == other.topology)
        #expect(compact.topology != IslandPresentation.compact(primary: .timer, secondary: .call).topology)
        #expect(compact.topology != IslandPresentation.hidden(peek: false).topology)
        #expect(IslandPresentation.home.topology == IslandPresentation.expanded(.timer).topology)
    }

    @Test func families() {
        #expect(IslandPresentation.home.isExpandedFamily)
        #expect(IslandPresentation.drop(targeted: false).isExpandedFamily)
        #expect(!IslandPresentation.idle.isExpandedFamily)
        #expect(IslandPresentation.idle.isRestingPill)
        #expect(IslandPresentation.compact(primary: .call, secondary: nil).isRestingPill)
        #expect(!IslandPresentation.hidden(peek: true).isVisible)
    }
}
