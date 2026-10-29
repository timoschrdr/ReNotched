import AppKit
import CoreAudio

/// Observes volume and mute state of the default output device.
final class VolumeMonitor {
    /// Level, muted, and the headphones' SF Symbol while audio plays through headphones (nil for speakers).
    var onChange: ((Float, Bool, String?) -> Void)?
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
    private var keyMonitor: Any?
    /// Symbol of the current Bluetooth output, looked up once per device switch.
    private var bluetoothSymbol: String?
    private static let headphoneJack: UInt32 = 0x6864_706E // 'hdpn': wired headphones on the built-in output

    func start() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in self?.attach() }
        defaultBlock = block
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &addr, .main, block)
        attach()
        watchVolumeKeys()
    }

    /// Pressing "volume down" at 0 or "volume up" at the maximum changes nothing, so Core Audio stays silent.
    /// macOS still shows its overlay then, so the island does too: the volume keys are watched as well.
    private func watchVolumeKeys() {
        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .systemDefined) { [weak self] event in
            guard event.subtype.rawValue == 8 else { return }                 // auxiliary (media) keys
            let key = (event.data1 & 0xFFFF_0000) >> 16, down = (event.data1 & 0xFF00) >> 8 == 0x0A
            guard down, let self, self.lastVolume >= 0, Date() > self.ignoreUntil else { return }
            let atBottom = key == 1 && (self.lastVolume <= 0.0005 || self.lastMuted)   // NX_KEYTYPE_SOUND_DOWN
            let atTop = key == 0 && self.lastVolume >= 0.9995 && !self.lastMuted      // NX_KEYTYPE_SOUND_UP
            if atBottom || atTop {
                // let Core Audio report a real change first; only announce if nothing changed
                let before = (self.lastVolume, self.lastMuted)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    if self.lastVolume == before.0 && self.lastMuted == before.1 { self.onChange?(self.lastVolume, self.lastMuted, self.headphoneSymbol()) }
                }
            }
        }
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
        let btName = Self.bluetoothName(of: id)
        bluetoothSymbol = btName.flatMap(Self.headphoneSymbol(bluetoothName:))
        if switched, let btName { onBluetoothOutput?(btName) }

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

    /// Bluetooth headphones (by model), wired headphones in the jack, or nil for the speakers.
    /// Bluetooth speakers such as a HomePod or Sonos are not headphones and keep the speaker symbol.
    private func headphoneSymbol() -> String? {
        if let bluetoothSymbol { return bluetoothSymbol }
        var source: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var a = Self.address(kAudioDevicePropertyDataSource)
        guard AudioObjectHasProperty(device, &a),
              AudioObjectGetPropertyData(device, &a, 0, nil, &size, &source) == noErr else { return nil }
        return source == Self.headphoneJack ? HeadphoneSymbol.generic : nil
    }

    /// The model symbol for Bluetooth headphones, nil for a Bluetooth speaker (HomePod, Sonos, …).
    private static func headphoneSymbol(bluetoothName name: String) -> String? {
        let d = HeadphoneSymbol.pairedDevice(named: name)
        let symbol = HeadphoneSymbol.symbol(for: d, name: name)
        guard symbol == HeadphoneSymbol.generic, let d else { return symbol }
        // audio device class: wearable headset, hands-free or headphones
        return d.deviceClassMajor == 4 && [1, 2, 6].contains(d.deviceClassMinor) ? symbol : nil
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
        if announce && changed && Date() > ignoreUntil { onChange?(volume, muted, headphoneSymbol()) }
    }
}
