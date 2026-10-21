import SwiftUI
import UniformTypeIdentifiers

// MARK: Home

/// Opened by clicking the notch or idle pill: last media and quick timers.
struct HomeView: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        VStack(alignment: .leading, spacing: 12 * s) {
            if model.homeHasMedia {
                HomeMediaRow(service: model.nowPlaying)
            }
            if model.settings.timerEnabled {
                HStack {
                    Label("Timer", systemImage: "timer")
                        .font(.system(size: 13 * s, weight: .semibold))
                        .foregroundStyle(NotchColor.orange)
                    Spacer()
                    settingsButton
                }
                HStack(spacing: 6 * s) {
                    ForEach(TimerService.presets, id: \.self) { preset in
                        Button(TimeFormatting.presetLabel(seconds: preset)) {
                            model.startTimer(preset)
                        }
                        .buttonStyle(ChipButtonStyle(scale: s))
                        .accessibilityLabel(Text("Start \(TimeFormatting.spoken(preset)) timer"))
                    }
                }
            } else {
                HStack {
                    Text("Nothing live right now")
                        .font(.system(size: 13 * s, weight: .medium))
                        .foregroundStyle(NotchColor.secondaryText)
                    Spacer()
                    settingsButton
                }
            }
        }
        .padding(.horizontal, 20 * s)
        .frame(maxHeight: .infinity)
    }

    private var settingsButton: some View {
        Button {
            model.collapse()
            model.onOpenSettings?()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13 * s, weight: .semibold))
                .foregroundStyle(NotchColor.secondaryText)
                .frame(width: 24 * s, height: 24 * s)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Settings"))
        .help("Settings")
    }
}

private struct HomeMediaRow: View {
    let service: NowPlayingService
    @Environment(\.notchScale) private var s

    var body: some View {
        let info = service.info
        HStack(spacing: 12 * s) {
            Button { service.openSourceApp() } label: {
                ArtworkView(artwork: service.artwork, fallbackIcon: service.appIcon, size: 44 * s, cornerRadius: 10 * s)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(Text("Open player"))
            VStack(alignment: .leading, spacing: 2 * s) {
                Text(info?.title ?? "")
                    .font(.system(size: 14 * s, weight: .semibold))
                    .foregroundStyle(.white)
                Text(info?.artist ?? "")
                    .font(.system(size: 12 * s))
                    .foregroundStyle(NotchColor.secondaryText)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            GlyphButton(symbol: info?.isPlaying == true ? "pause.fill" : "play.fill", size: 20 * s, label: info?.isPlaying == true ? "Pause" : "Play") {
                service.togglePlayPause()
            }
            GlyphButton(symbol: "forward.fill", size: 16 * s, label: "Next Track") { service.nextTrack() }
        }
    }
}

// MARK: Alerts

struct AlertView: View {
    let model: IslandModel
    let alert: IslandAlert
    /// Middle width kept clear for the camera in notch style.
    var cameraGap: CGFloat = 0
    @Environment(\.notchScale) private var s

    var body: some View {
        switch alert {
        case .charging(let level, let isCharging):
            let lowPower = model.power.snapshot?.isLowPowerMode == true
            let tint = lowPower ? NotchColor.yellow : NotchColor.green
            AlertRow(cameraGap: cameraGap) {
                Text(isCharging ? "Charging" : "Connected")
            } trailing: {
                BatteryLabel(level: level, isCharging: true, tint: tint)
            }
            .accessibilityElement(children: .combine)
        case .lowBattery(let level):
            AlertRow(cameraGap: cameraGap) {
                Text("Low Battery")
            } trailing: {
                BatteryLabel(level: level, isCharging: false, tint: NotchColor.red)
            }
            .accessibilityElement(children: .combine)
        case .headphones(let name, let symbol):
            AlertRow(cameraGap: cameraGap) {
                HStack(spacing: 6 * s) {
                    Image(systemName: symbol)
                        .font(.system(size: 15 * s, weight: .medium))
                    Text(name)
                        .font(.system(size: 13 * s, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            } trailing: {
                Text("Connected")
                    .foregroundStyle(NotchColor.green)
            }
            .accessibilityElement(children: .combine)
        case .timerFinished:
            TimerFinishedView(model: model)
        case .welcome:
            AlertRow(cameraGap: cameraGap) {
                Text("Dynamic Notch")
            } trailing: {
                Text("Ready")
                    .foregroundStyle(NotchColor.green)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// Leading content left of the camera, trailing content right of it.
private struct AlertRow<Leading: View, Trailing: View>: View {
    var cameraGap: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing
    @Environment(\.notchScale) private var s

    var body: some View {
        GeometryReader { geometry in
            let edge: CGFloat = (cameraGap > 0 ? 14 : 20) * s
            let side = max(0, (geometry.size.width - cameraGap) / 2 - edge - (cameraGap > 0 ? 6 : 4))
            HStack(spacing: 0) {
                leading
                    .frame(width: side, alignment: .leading)
                Spacer(minLength: 0)
                trailing
                    .frame(width: side, alignment: .trailing)
            }
            .padding(.horizontal, edge)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .font(.system(size: 14 * s, weight: .semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
    }
}

private struct BatteryLabel: View {
    var level: Int
    var isCharging: Bool
    var tint: Color
    @Environment(\.notchScale) private var s

    var body: some View {
        HStack(spacing: 6 * s) {
            Text("\(level)%")
                .monospacedDigit()
                .foregroundStyle(tint)
            BatteryGlyph(level: level, isCharging: isCharging, color: tint, width: 27 * s)
        }
    }
}

private struct TimerFinishedView: View {
    let model: IslandModel
    @Environment(\.notchScale) private var s

    var body: some View {
        HStack(spacing: 12 * s) {
            Image(systemName: "bell.fill")
                .font(.system(size: 24 * s, weight: .semibold))
                .foregroundStyle(NotchColor.orange)
                .phaseAnimator([0.0, -16, 14, -10, 8, 0, 0, 0]) { bell, angle in
                    bell.rotationEffect(.degrees(angle), anchor: .top)
                } animation: { _ in
                    .easeInOut(duration: 0.11)
                }
                .frame(width: 44 * s)
            VStack(alignment: .leading, spacing: 0) {
                Text("Timer")
                    .font(.system(size: 13 * s, weight: .semibold))
                    .foregroundStyle(NotchColor.orange)
                Text("Done")
                    .font(.system(size: 26 * s, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 8 * s)
            CircleButton(symbol: "arrow.counterclockwise", size: 48 * s, label: "Repeat Timer") { model.repeatTimer() }
            CircleButton(symbol: "xmark", size: 48 * s, foreground: .black, background: NotchColor.orange, label: "Stop Timer") {
                model.stopTimerAlarm()
            }
        }
        .padding(.horizontal, 20 * s)
    }
}

// MARK: Drop

struct DropView: View {
    let model: IslandModel
    let isTargeted: Bool
    @Environment(\.notchScale) private var s

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24 * s, style: .continuous)
                .strokeBorder(
                    NotchColor.blue.opacity(isTargeted ? 0.9 : 0.4),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                )
                .padding(12 * s)
            VStack(spacing: 8 * s) {
                ZStack {
                    Circle()
                        .fill(NotchColor.blue.opacity(isTargeted ? 0.35 : 0.18))
                        .frame(width: 46 * s, height: 46 * s)
                    Image(systemName: "dot.radiowaves.up.forward")
                        .font(.system(size: 20 * s, weight: .semibold))
                        .foregroundStyle(NotchColor.blue)
                }
                .scaleEffect(isTargeted ? 1.1 : 1)
                Text(isTargeted ? "Release to AirDrop" : "Drop to AirDrop")
                    .font(.system(size: 13 * s, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.4), value: isTargeted)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: Binding(
            get: { model.isDropTargeted },
            set: { model.isDropTargeted = $0 }
        )) { providers in
            loadURLs(from: providers)
            return true
        }
        .accessibilityElement(children: .combine)
    }

    private func loadURLs(from providers: [NSItemProvider]) {
        let group = DispatchGroup()
        let collector = URLCollector()
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url { collector.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            MainActor.assumeIsolated {
                _ = model.airDrop(collector.urls)
            }
        }
    }
}

/// Collects URLs from item-provider callbacks, which arrive on background threads.
private final class URLCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []

    func append(_ url: URL) {
        lock.lock()
        storage.append(url)
        lock.unlock()
    }

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
