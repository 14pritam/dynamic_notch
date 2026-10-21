import CoreAudio
import Foundation

/// Thin, failure-tolerant wrappers around the Core Audio property API.
enum AudioHW {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    static func value<T>(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress, default fallback: T) -> T {
        var address = address
        var value = fallback
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        return status == noErr ? value : fallback
    }

    static func objects(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> [AudioObjectID] {
        var address = address
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        let status = ids.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, buffer.baseAddress!)
        }
        guard status == noErr else { return [] }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
    }

    static func string(_ object: AudioObjectID, _ address: AudioObjectPropertyAddress) -> String? {
        var address = address
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, pointer)
        }
        guard status == noErr, let value else { return nil }
        return value.takeRetainedValue() as String
    }

    static func defaultOutputDevice() -> AudioDeviceID {
        value(system, address(kAudioHardwarePropertyDefaultOutputDevice), default: AudioDeviceID(0))
    }

    static func deviceName(_ device: AudioDeviceID) -> String? {
        string(device, address(kAudioObjectPropertyName))
    }

    static func isBluetooth(_ device: AudioDeviceID) -> Bool {
        let transport: UInt32 = value(device, address(kAudioDevicePropertyTransportType), default: 0)
        return transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE
    }

    static func inputDevices() -> [AudioDeviceID] {
        objects(system, address(kAudioHardwarePropertyDevices)).filter { device in
            var streams = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
            var size: UInt32 = 0
            return AudioObjectGetPropertyDataSize(device, &streams, 0, nil, &size) == noErr && size > 0
        }
    }

    static func isRunningSomewhere(_ device: AudioDeviceID) -> Bool {
        let running: UInt32 = value(device, address(kAudioDevicePropertyDeviceIsRunningSomewhere), default: 0)
        return running != 0
    }

    struct InputProcess: Equatable {
        var pid: pid_t
        var bundleIdentifier: String?
    }

    /// Processes with an active input stream (macOS 14+). Nil if the system can't say.
    static func processesUsingInput() -> [InputProcess]? {
        var listAddress = address(kAudioHardwarePropertyProcessObjectList)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &listAddress, 0, nil, &size) == noErr else { return nil }
        return objects(system, listAddress).compactMap { process in
            let running: UInt32 = value(process, address(kAudioProcessPropertyIsRunningInput), default: 0)
            guard running != 0 else { return nil }
            let pid: pid_t = value(process, address(kAudioProcessPropertyPID), default: 0)
            return InputProcess(pid: pid, bundleIdentifier: string(process, address(kAudioProcessPropertyBundleID)))
        }
    }

    /// Registers a listener that runs on the main queue. Returns a token for removal.
    @discardableResult
    static func listen(
        _ object: AudioObjectID,
        _ address: AudioObjectPropertyAddress,
        handler: @escaping @MainActor () -> Void
    ) -> Listener? {
        var address = address
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            MainActor.assumeIsolated { handler() }
        }
        guard AudioObjectAddPropertyListenerBlock(object, &address, .main, block) == noErr else { return nil }
        return Listener(object: object, address: address, block: block)
    }

    struct Listener {
        let object: AudioObjectID
        let address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock

        func remove() {
            var address = address
            AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
        }
    }
}
