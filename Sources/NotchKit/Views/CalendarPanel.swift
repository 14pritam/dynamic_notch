import SwiftUI

/// This month on the left, what's coming up on the right.
struct CalendarPanelBody: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        let calendar = model.calendar
        HStack(alignment: .top, spacing: 18 * s) {
            TimelineView(.everyMinute) { context in
                MonthGrid(today: context.date)
            }
            .frame(width: 196 * s)
            VStack(alignment: .leading, spacing: 6 * s) {
                switch calendar.access {
                case .notAsked:
                    Text("See your next events here.")
                        .font(.system(size: 12 * s, weight: .medium))
                        .foregroundStyle(NotchColor.secondaryText)
                    Button("Connect Calendar") { calendar.requestAccess() }
                        .buttonStyle(ChipButtonStyle(tint: NotchColor.red, scale: s))
                        .fixedSize()
                case .denied:
                    Text("Calendar access is off for Dynamic Notch.")
                        .font(.system(size: 12 * s, weight: .medium))
                        .foregroundStyle(NotchColor.secondaryText)
                    Button("Open Settings") { calendar.openPrivacySettings() }
                        .buttonStyle(ChipButtonStyle(tint: .white, scale: s))
                        .fixedSize()
                case .granted:
                    TimelineView(.everyMinute) { context in
                        let upcoming = CalendarRules.upcoming(in: calendar.events, at: context.date, limit: 3)
                        if upcoming.isEmpty {
                            Text("Nothing else coming up today.")
                                .font(.system(size: 12 * s, weight: .medium))
                                .foregroundStyle(NotchColor.secondaryText)
                        } else {
                            VStack(alignment: .leading, spacing: 4 * s) {
                                ForEach(upcoming) { event in
                                    EventLine(event: event, now: context.date)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                    Button("Open Calendar") {
                        calendar.openCalendarApp()
                        model.collapse()
                    }
                    .buttonStyle(ChipButtonStyle(tint: .white, scale: s))
                    .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.bottom, 4 * s)
    }
}

private struct EventLine: View {
    let event: CalendarEvent
    let now: Date
    @Environment(\.notchScale) private var s

    var body: some View {
        HStack(spacing: 8 * s) {
            Capsule()
                .fill(NotchColor.accent(event.color))
                .frame(width: 3 * s, height: 22 * s)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title)
                    .font(.system(size: 12 * s, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(CalendarRules.timeRange(for: event, at: now))
                    .font(.system(size: 10 * s, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(event.isHappening(at: now) ? NotchColor.green : NotchColor.secondaryText)
                    .lineLimit(1)
            }
        }
    }
}

/// A small month, today circled in red, like the Calendar app's sidebar.
private struct MonthGrid: View {
    let today: Date
    @Environment(\.notchScale) private var s

    var body: some View {
        let month = MonthLayout(containing: today)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        VStack(alignment: .leading, spacing: 3 * s) {
            Text(today.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 12 * s, weight: .semibold))
                .foregroundStyle(.white)
            LazyVGrid(columns: columns, spacing: 1 * s) {
                // Weekday headers and day cells need distinct ids inside one grid.
                ForEach(Array(month.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 8 * s, weight: .semibold))
                        .foregroundStyle(NotchColor.secondaryText)
                }
                ForEach(month.cells.indices.map { $0 + 100 }, id: \.self) { index in
                    let day = month.cells[index - 100]
                    let isToday = day == month.today
                    Text(day.map(String.init) ?? "")
                        .font(.system(size: 9 * s, weight: isToday ? .bold : .medium))
                        .monospacedDigit()
                        .foregroundStyle(isToday ? .white : .white.opacity(0.8))
                        .frame(width: 16 * s, height: 12 * s)
                        .background(Circle().fill(isToday ? NotchColor.red : .clear).frame(width: 14 * s, height: 14 * s))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(today.formatted(date: .complete, time: .omitted)))
    }
}
