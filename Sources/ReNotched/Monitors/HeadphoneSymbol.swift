import Foundation
import IOBluetooth

/// The SF Symbol for a pair of headphones: the exact AirPods or Beats model where it can be told, otherwise
/// generic headphones. The model comes from the Bluetooth product ID (Apple's vendor ID 0x004C), so renamed
/// AirPods are still recognised; the name is only a fallback.
enum HeadphoneSymbol {
    static let generic = "headphones"

    private static let apple: UInt16 = 0x004C
    private static let byProduct: [UInt16: String] = [
        0x2002: "airpods", 0x200F: "airpods",                         // AirPods (1st, 2nd generation)
        0x2013: "airpods.gen3",                                       // AirPods (3rd generation)
        0x2019: "airpods.gen4", 0x201B: "airpods.gen4",               // AirPods 4
        0x200E: "airpods.pro", 0x2014: "airpods.pro", 0x2024: "airpods.pro", // AirPods Pro, Pro 2
        0x2027: "airpods.pro.gen3",                                   // AirPods Pro 3
        0x200A: "airpods.max", 0x201F: "airpods.max",                 // AirPods Max
        0x200B: "beats.powerbeats.pro", 0x201D: "beats.powerbeats.pro",
        0x2011: "beats.studiobuds",
        0x2012: "beats.fitpro",
    ]

    static func symbol(for device: IOBluetoothDevice?, name: String) -> String {
        if let device, device.responds(to: Selector(("vendorID"))), device.responds(to: Selector(("productID"))),
           (device.value(forKey: "vendorID") as? NSNumber)?.uint16Value == apple,
           let pid = (device.value(forKey: "productID") as? NSNumber)?.uint16Value,
           let symbol = byProduct[pid] {
            return symbol
        }
        let n = name.lowercased()
        if n.contains("airpods max") { return "airpods.max" }
        if n.contains("airpods pro") { return "airpods.pro" }
        if n.contains("airpods") { return "airpods" }
        if n.contains("powerbeats") { return "beats.powerbeats.pro" }
        if n.contains("beats") { return "beats.headphones" }
        return generic
    }

    /// The paired device with this name (Core Audio only knows the name of a Bluetooth output).
    static func pairedDevice(named name: String) -> IOBluetoothDevice? {
        ((IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []).first { $0.name == name }
    }
}
