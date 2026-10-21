import CoreAudio
import Foundation

/// Reports when Bluetooth headphones become the sound output, like the iPhone's AirPods alert.
@MainActor
public final class AudioRouteMonitor {
    public var onAlert: ((IslandAlert) -> Void)?

    private var currentDevice: AudioDeviceID = 0
    private var listener: AudioHW.Listener?
    /// AirPods re-register when they switch to the call profile; don't announce them twice.
    private var lastAnnounced: (name: String, date: Date)?

    public init() {}

    public func start() {
        guard listener == nil else { return }
        currentDevice = AudioHW.defaultOutputDevice()
        listener = AudioHW.listen(AudioHW.system, AudioHW.address(kAudioHardwarePropertyDefaultOutputDevice)) { [weak self] in
            self?.outputChanged()
        }
    }

    public func stop() {
        listener?.remove()
        listener = nil
    }

    private func outputChanged() {
        let device = AudioHW.defaultOutputDevice()
        guard device != currentDevice else { return }
        currentDevice = device
        guard AudioHW.isBluetooth(device), let name = AudioHW.deviceName(device) else { return }
        if let lastAnnounced, lastAnnounced.name == name, Date().timeIntervalSince(lastAnnounced.date) < 60 {
            return
        }
        lastAnnounced = (name, Date())
        onAlert?(.headphones(name: name, symbol: HeadphoneSymbol.symbol(forDeviceName: name)))
    }
}
