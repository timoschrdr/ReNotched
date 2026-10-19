import Foundation
import IOBluetooth

/// Reports Bluetooth headphones connecting, including their battery level.
final class BluetoothMonitor: NSObject {
    var onConnect: ((String, Int?) -> Void)?
    private var registration: IOBluetoothUserNotification?

    func start() {
        registration = IOBluetoothDevice.register(forConnectNotifications: self, selector: #selector(connected(_:device:)))
    }

    @objc private func connected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard device.deviceClassMajor == 4 || device.deviceClassMajor == 0 else { return } // audio
        let name = (device.name ?? NSLocalizedString("Headphones", comment: "")).replacingOccurrences(of: " (von|of) .*$", with: "", options: .regularExpression)
        // The battery level often arrives shortly after connecting → wait briefly.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.onConnect?(name, Self.battery(of: device))
        }
    }

    private static func battery(of d: IOBluetoothDevice) -> Int? {
        for key in ["batteryPercentSingle", "batteryPercentCombined", "headsetBattery", "batteryPercent"] where d.responds(to: Selector(key)) {
            if let v = (d.value(forKey: key) as? NSNumber)?.intValue, (1...100).contains(v) { return v }
        }
        return nil
    }

}
