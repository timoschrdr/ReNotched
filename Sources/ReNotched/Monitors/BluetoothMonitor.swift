import AppKit
import IOBluetooth
import IOKit

/// Reports Bluetooth headphones and mice connecting, including their battery level.
/// Two signals feed it: IOBluetooth connect notifications and audio being routed to a Bluetooth output.
final class BluetoothMonitor: NSObject {
    /// Name, battery level, the SF Symbol of the model (see `HeadphoneSymbol`) and Apple's picture of it, if the Mac has one
    /// (see `DeviceImage`).
    var onConnect: ((String, Int?, String, String?) -> Void)?
    private var registration: IOBluetoothUserNotification?
    private var lastShown: [String: Date] = [:]
    private var startDate = Date()
    private var wakeDate = Date.distantPast

    func start() {
        startDate = Date()
        registration = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) {
            [weak self] _ in self?.wakeDate = Date()
        }
    }

    @objc private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Registering reports devices that are already connected → ignore the first seconds.
        guard Date().timeIntervalSince(startDate) > 3 else { return }
        if Self.isMouse(device) {
            // A mouse reconnects by itself after every sleep: only show it when it is switched on or newly paired.
            guard Date().timeIntervalSince(wakeDate) > 15 else { return }
            announce(name: device.name ?? "", device: device, delay: 2)   // its battery shows up a little later
        } else if Self.isAudio(device) {   // no keyboards, phones, …
            announce(name: device.name ?? "", device: device)
        }
    }

    /// Shows the animation for a connected audio device. At most once a minute per device.
    func announce(name rawName: String, device: IOBluetoothDevice? = nil, delay: Double = 1.2) {
        let name = Self.clean(rawName)
        if let last = lastShown[name], Date().timeIntervalSince(last) < 60 { return }
        lastShown[name] = Date()
        // The battery level often arrives shortly after connecting → wait briefly.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
            let d = device ?? paired.first { Self.clean($0.name ?? "") == name }
            let symbol = d.map(Self.isMouse) == true ? Self.mouseSymbol(d) : HeadphoneSymbol.symbol(for: d, name: rawName)
            self?.onConnect?(name, d.flatMap(Self.battery), symbol,
                             DeviceImage.path(forProductID: HeadphoneSymbol.appleProductID(of: d),
                                              color: Self.hid(d?.addressString, "ColorID")))
        }
    }

    private static func clean(_ name: String) -> String {
        let n = name.replacingOccurrences(of: " (von|of) .*$", with: "", options: .regularExpression)
        return n.isEmpty ? NSLocalizedString("Headphones", comment: "") : n
    }

    /// Audio class, or an A2DP / hands-free / headset service (some headsets report no device class).
    private static func isAudio(_ d: IOBluetoothDevice) -> Bool {
        d.deviceClassMajor == 4 || [0x110B, 0x111E, 0x1108].contains { d.getServiceRecord(for: IOBluetoothSDPUUID(uuid16: BluetoothSDPUUID16($0))) != nil }
    }

    /// A Magic Mouse, or any Bluetooth mouse (peripheral class, pointing device).
    private static func isMouse(_ d: IOBluetoothDevice) -> Bool {
        if let pid = HeadphoneSymbol.appleProductID(of: d), DeviceImage.magicMice.contains(pid) { return true }
        return d.deviceClassMajor == 5 && d.deviceClassMinor & 0x20 != 0
    }

    private static func mouseSymbol(_ d: IOBluetoothDevice?) -> String {
        let magic = HeadphoneSymbol.appleProductID(of: d).map(DeviceImage.magicMice.contains) == true
        return magic ? "magicmouse.fill" : "computermouse.fill"
    }

    private static func battery(of d: IOBluetoothDevice) -> Int? {
        for key in ["batteryPercentSingle", "batteryPercentCombined", "headsetBattery", "batteryPercent"] where d.responds(to: Selector(key)) {
            if let v = (d.value(forKey: key) as? NSNumber)?.intValue, (1...100).contains(v) { return v }
        }
        // AirPods report each earbud separately: show the emptier one
        let buds = ["batteryPercentLeft", "batteryPercentRight"].compactMap { key -> Int? in
            guard d.responds(to: Selector(key)), let v = (d.value(forKey: key) as? NSNumber)?.intValue,
                  (1...100).contains(v) else { return nil }
            return v
        }
        if let min = buds.min() { return min }
        return hid(d.addressString, "BatteryPercent").flatMap { (1...100).contains($0) ? $0 : nil }
    }

    /// A number the device's HID service keeps in the I/O Registry: mice and keyboards report their battery
    /// ("BatteryPercent") and colour ("ColorID") there, not through IOBluetooth.
    private static func hid(_ address: String?, _ key: String) -> Int? {
        guard let address = address?.lowercased().replacingOccurrences(of: ":", with: "-") else { return nil }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleDeviceManagementHIDEventService"),
                                           &iterator) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            func property(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            guard (property("DeviceAddress") as? String)?.lowercased() == address,
                  let value = (property(key) as? NSNumber)?.intValue else { continue }
            return value
        }
        return nil
    }
}
