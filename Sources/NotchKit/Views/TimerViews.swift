import SwiftUI

// The Timer panel and the running timer and stopwatch, styled after the iPhone's Clock: one
// timer orange throughout. Setting a time slides a ruler of minute ticks under a fixed pointer.

// MARK: Ruler

/// Minute ticks that slide under a pointer fixed in the middle. Ticks up to the pointer are lit,
/// both ends fade out, and labels sit over every fifth minute. Drag to slide it (it follows the
/// pointer smoothly, then settles on a whole minute) or click a tick to jump there.
struct SlidingRuler: View {
    var range: ClosedRange<Int>
    var value: Int
    var tint: Color = NotchColor.orange
    var isEnabled = true
    var onChange: (Int) -> Void

    /// The ruler's position while a drag is in progress, in fractional minutes.
    @State private var dragValue: Double?
    @State private var dragStart: Double?
    @Environment(\.notchScale) private var s

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let center = width / 2
            let shown = dragValue ?? Double(value)
            let visible = Int((width / spacing / 2).rounded(.up)) + 1
            let first = max(range.lowerBound, Int(shown.rounded(.down)) - visible)
            let last = min(range.upperBound, Int(shown.rounded(.up)) + visible)
            ZStack(alignment: .topLeading) {
                if first <= last {
                    ForEach(first...last, id: \.self) { minute in
                        let x = center + CGFloat(Double(minute) - shown) * spacing
                        let lit = Double(minute) <= shown + 0.001
                        if minute % 5 == 0 {
                            Text("\(minute)")
                                .font(.system(size: 12 * s, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(tint.opacity(lit ? 1 : 0.35))
                                .fixedSize()
                                .position(x: x, y: 8 * s)
                        }
                        Capsule()
                            .fill(tint.opacity(lit ? 1 : 0.3))
                            .frame(width: 3.5 * s, height: tickHeight)
                            .position(x: x, y: tickTop + tickHeight / 2)
                    }
                }
                Triangle()
                    .fill(tint.opacity(isEnabled ? 1 : 0.4))
                    .frame(width: 11 * s, height: 8 * s)
                    .position(x: center, y: tickTop + tickHeight + 10 * s)
            }
            // Both ends fade, so the ruler seems to run on past the edges.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.16),
                        .init(color: .black, location: 0.84),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let start = dragStart ?? Double(value)
                        dragStart = start
                        if abs(drag.translation.width) < 2 {
                            return
                        }
                        // Dragging left pulls later minutes under the pointer, like a tape.
                        let next = clamp(start - Double(drag.translation.width / spacing))
                        dragValue = next
                        let minute = Int(next.rounded())
                        if minute != value { onChange(minute) }
                    }
                    .onEnded { drag in
                        defer { dragStart = nil }
                        if abs(drag.translation.width) < 2 {
                            // A click: jump to the tick under the pointer.
                            let tapped = Int(clamp(Double(value) + Double((drag.location.x - center) / spacing)).rounded())
                            withAnimation(.spring(duration: 0.45, bounce: 0.2)) { onChange(tapped) }
                            return
                        }
                        withAnimation(.spring(duration: 0.35, bounce: 0.25)) { dragValue = nil }
                    },
                including: isEnabled ? .all : .none
            )
        }
        .frame(height: tickTop + tickHeight + 16 * s)
        .accessibilityElement()
        .accessibilityLabel(Text("Minutes"))
        .accessibilityValue(Text("\(value)"))
        .accessibilityAdjustableAction { direction in
            guard isEnabled else { return }
            onChange(Int(clamp(Double(value + (direction == .increment ? 1 : -1)))))
        }
    }

    private var spacing: CGFloat { 14 * s }
    private var tickTop: CGFloat { 20 * s }
    private var tickHeight: CGFloat { 34 * s }

    private func clamp(_ minute: Double) -> Double {
        min(max(minute, Double(range.lowerBound)), Double(range.upperBound))
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

extension TimerPanelMode {
    var title: LocalizedStringKey {
        switch self {
        case .timer: "Timer"
        case .focus: "Pomodoro"
        case .stopwatch: "Stopwatch"
        }
    }
}

// MARK: Panel

/// Pick a mode, slide the ruler, press Start.
struct TimerPanelBody: View {
    @Bindable var model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        let mode = model.timerPanelMode
        let tint = NotchColor.orange
        VStack(alignment: .leading, spacing: 4 * s) {
            HStack(spacing: 4 * s) {
                ForEach(TimerPanelMode.allCases, id: \.self) { option in
                    ModeTab(title: option.title, isSelected: option == mode) {
                        withAnimation(.spring(duration: 0.3, bounce: 0.2)) { model.timerPanelMode = option }
                    }
                }
                Spacer(minLength: 8 * s)
                Button("Start") { model.startFromPanel() }
                    .buttonStyle(StartButtonStyle(scale: s))
                    .keyboardShortcut(.defaultAction)
            }
            HStack(alignment: .center, spacing: 16 * s) {
                switch mode {
                case .timer:
                    SlidingRuler(range: TimerRuler.timerRange, value: model.timerPanelMinutes) { minutes in
                        pick(minutes, current: model.timerPanelMinutes) { model.timerPanelMinutes = $0 }
                    }
                case .focus:
                    SlidingRuler(range: TimerRuler.focusRange, value: model.focusPanelMinutes) { minutes in
                        pick(minutes, current: model.focusPanelMinutes) { model.focusPanelMinutes = $0 }
                    }
                case .stopwatch:
                    SlidingRuler(range: 0...60, value: 0, isEnabled: false) { _ in }
                }
                VStack(alignment: .trailing, spacing: 0) {
                    Text(bigText(mode))
                        .font(.system(size: 40 * s, weight: .thin))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .fixedSize()
                        .animation(.snappy(duration: 0.2), value: bigText(mode))
                    if mode == .focus {
                        Text("then a \(model.settings.breakMinutes) min break")
                            .font(.system(size: 10 * s, weight: .medium))
                            .foregroundStyle(NotchColor.secondaryText)
                            .fixedSize()
                    }
                }
                .frame(minWidth: 116 * s, alignment: .trailing)
            }
        }
    }

    private func pick(_ minutes: Int, current: Int, set: (Int) -> Void) {
        guard minutes != current else { return }
        set(minutes)
        Haptics.perform(enabled: model.settings.hapticsEnabled)
    }

    private func bigText(_ mode: TimerPanelMode) -> String {
        switch mode {
        case .timer: TimeFormatting.clock(TimeInterval(model.timerPanelMinutes * 60))
        case .focus: TimeFormatting.clock(TimeInterval(model.focusPanelMinutes * 60))
        case .stopwatch: "0:00.0"
        }
    }
}

/// The selected mode reads white with an orange underline; the others are grey.
private struct ModeTab: View {
    var title: LocalizedStringKey
    var isSelected: Bool
    var action: () -> Void
    @Environment(\.notchScale) private var s

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13 * s, weight: .semibold))
                .foregroundStyle(isSelected ? .white : NotchColor.secondaryText)
                .padding(.horizontal, 8 * s)
                .frame(height: 28 * s)
                .overlay(alignment: .bottom) {
                    if isSelected {
                        Capsule().fill(NotchColor.orange).frame(height: 2.5 * s).padding(.horizontal, 8 * s)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct StartButtonStyle: ButtonStyle {
    var scale: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15 * scale, weight: .semibold))
            .foregroundStyle(NotchColor.orange)
            .padding(.horizontal, 22 * scale)
            .frame(height: 34 * scale)
            .background(Capsule().fill(NotchColor.orange.opacity(configuration.isPressed ? 0.32 : 0.22)))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

// MARK: Running

/// Pause and cancel on the left, the label and the big time on the right, like the iPhone's
/// timer Live Activity.
private struct RunningClock<Time: View>: View {
    var isPaused: Bool
    var label: LocalizedStringKey
    var pauseLabel: LocalizedStringKey
    var cancelLabel: LocalizedStringKey
    var togglePause: () -> Void
    var cancel: () -> Void
    @ViewBuilder var time: Time
    @Environment(\.notchScale) private var s

    var body: some View {
        HStack(spacing: 12 * s) {
            CircleButton(
                symbol: isPaused ? "play.fill" : "pause.fill",
                size: 46 * s,
                foreground: NotchColor.orange,
                background: NotchColor.orange.opacity(0.3),
                label: pauseLabel,
                action: togglePause
            )
            CircleButton(symbol: "xmark", size: 46 * s, label: cancelLabel, action: cancel)
            Spacer(minLength: 8 * s)
            HStack(alignment: .firstTextBaseline, spacing: 8 * s) {
                Text(label)
                    .font(.system(size: 14 * s, weight: .medium))
                time
                    .font(.system(size: 46 * s, weight: .thin))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(NotchColor.orange.opacity(isPaused ? 0.6 : 1))
        }
        .padding(.horizontal, 20 * s)
    }
}

struct TimerExpandedView: View {
    let model: IslandModel

    var body: some View {
        let timer = model.timer.timer
        let isPaused = timer?.isPaused == true
        RunningClock(
            isPaused: isPaused,
            label: (timer?.mode ?? .plain).title,
            pauseLabel: isPaused ? "Resume Timer" : "Pause Timer",
            cancelLabel: "Cancel Timer",
            togglePause: { model.timer.togglePause() },
            cancel: { model.cancelTimer() }
        ) {
            if let timer {
                CountdownText(timer: timer)
            }
        }
    }
}

struct StopwatchExpandedView: View {
    let model: IslandModel

    var body: some View {
        let isRunning = model.stopwatch.stopwatch?.isRunning == true
        RunningClock(
            isPaused: !isRunning,
            label: "Stopwatch",
            pauseLabel: isRunning ? "Pause Stopwatch" : "Resume Stopwatch",
            cancelLabel: "Reset Stopwatch",
            togglePause: { model.stopwatch.togglePause() },
            cancel: { model.resetStopwatch() }
        ) {
            TimelineView(.animation(minimumInterval: 0.1, paused: !isRunning)) { context in
                Text(StopwatchFormat.text(model.stopwatch.elapsed(at: context.date)))
            }
        }
    }
}

enum StopwatchFormat {
    /// "0:07.4", "12:30.0", "1:02:03".
    static func text(_ elapsed: TimeInterval) -> String {
        let value = max(0, elapsed)
        if value >= 3600 { return TimeFormatting.clock(value) }
        let tenths = Int((value * 10).rounded(.down)) % 10
        return TimeFormatting.clock(value) + ".\(tenths)"
    }
}
