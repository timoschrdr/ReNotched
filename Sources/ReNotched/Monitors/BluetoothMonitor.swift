import Foundation
import IOBluetooth

/// Reports Bluetooth headphones connecting, including their battery level.
/// Two signals feed it: IOBluetooth connect notifications and audio being routed to a Bluetooth output.
final class BluetoothMonitor: NSObject {
    /// Name, battery level and the SF Symbol of the model (see `HeadphoneSymbol`).
    var onConnect: ((String, Int?, String) -> Void)?
    private var registration: IOBluetoothUserNotification?
    private var lastShown: [String: Date] = [:]
    private var startDate = Date()

    func start() {
        startDate = Date()
        registration = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
    }

    @objc private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        // Registering reports devices that are already connected → ignore the first seconds.
        guard Date().timeIntervalSince(startDate) > 3, Self.isAudio(device) else { return }   // no mice, keyboards, …
        announce(name: device.name ?? "", device: device)
    }

    /// Shows the animation for a connected audio device. At most once a minute per device.
    func announce(name rawName: String, device: IOBluetoothDevice? = nil) {
        let name = Self.clean(rawName)
        if let last = lastShown[name], Date().timeIntervalSince(last) < 60 { return }
        lastShown[name] = Date()
        // The battery level often arrives shortly after connecting → wait briefly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
            let d = device ?? paired.first { Self.clean($0.name ?? "") == name }
            self?.onConnect?(name, d.flatMap(Self.battery), HeadphoneSymbol.symbol(for: d, name: rawName))
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
        return buds.min()
    }
}
