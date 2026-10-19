import CoreAudio
import Foundation

/// Observes volume and mute state of the default output device.
final class VolumeMonitor {
    var onChange: ((Float, Bool) -> Void)?
    /// Called with the device name when audio switches to a Bluetooth output (e.g. headphones connecting).
    var onBluetoothOutput: ((String) -> Void)?
    private var ignoreUntil = Date.distantPast   // a device switch changes the volume too, which is not a key press

    private var device = AudioObjectID(kAudioObjectUnknown)
    private var lastVolume: Float = -1
    private var lastMuted = false
    private var addresses: [AudioObjectPropertyAddress] = []
    private var deviceBlock: AudioObjectPropertyListenerBlock?
    private var defaultBlock: AudioObjectPropertyListenerBlock?

    private static let virtualMainVolume: AudioObjectPropertySelector = 0x766D_7663 // 'vmvc'

    func start() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.attach() }
        defaultBlock = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main, block)
        attach()
    }

    private func attach() {
        detach()
        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id) == noErr,
              id != kAudioObjectUnknown else { return }
        let switched = device != kAudioObjectUnknown && id != device
        device = id
        ignoreUntil = Date().addingTimeInterval(1.5)
        if switched, let name = Self.bluetoothName(of: id) { onBluetoothOutput?(name) }

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.check(announce: true) }
        deviceBlock = block
        for var a in [
            Self.address(Self.virtualMainVolume),
            Self.address(kAudioDevicePropertyMute),
        ] {
            if AudioObjectHasProperty(device, &a) {
                AudioObjectAddPropertyListenerBlock(device, &a, .main, block)
                addresses.append(a)
            }
        }
        check(announce: false)
    }

    private func detach() {
        guard device != kAudioObjectUnknown, let block = deviceBlock else { return }
        for var a in addresses { AudioObjectRemovePropertyListenerBlock(device, &a, .main, block) }
        addresses.removeAll()
        deviceBlock = nil
    }

    private static func bluetoothName(of id: AudioObjectID) -> String? {
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var a = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyTransportType,
                                           mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &transport) == noErr,
              transport == kAudioDeviceTransportTypeBluetooth || transport == kAudioDeviceTransportTypeBluetoothLE else { return nil }
        var name: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        a.mSelector = kAudioObjectPropertyName
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    private static func address(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector,
                                   mScope: kAudioDevicePropertyScopeOutput,
                                   mElement: kAudioObjectPropertyElementMain)
    }

    private func check(announce: Bool) {
        var volume: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        var a = Self.address(Self.virtualMainVolume)
        guard AudioObjectGetPropertyData(device, &a, 0, nil, &size, &volume) == noErr else { return }

        var mute: UInt32 = 0
        var msize = UInt32(MemoryLayout<UInt32>.size)
        var m = Self.address(kAudioDevicePropertyMute)
        if AudioObjectHasProperty(device, &m) {
            AudioObjectGetPropertyData(device, &m, 0, nil, &msize, &mute)
        }
        let muted = mute != 0
        let changed = abs(volume - lastVolume) > 0.0005 || muted != lastMuted
        lastVolume = volume
        lastMuted = muted
        if announce && changed && Date() > ignoreUntil { onChange?(volume, muted) }
    }
}
