import AppKit

/// Apple's own picture of an AirPods, Beats or Magic Mouse model, the one macOS shows in Bluetooth settings.
///
/// Nothing of Apple's ships with ReNotched: the picture is read at runtime from the Mac's own CoreBluetoothUI
/// framework, through the product-ID map Apple keeps next to it (AssetPaths*.plist). These are private files,
/// so when a macOS version moves or drops them the lookup just finds nothing and the SF Symbol is used.
enum DeviceImage {
    private static let resources = "/System/Library/PrivateFrameworks/CoreBluetoothUI.framework/Versions/A/Resources"

    /// The picture of a model, and one per colour where Apple has them (colour ID → file).
    private struct Pictures { var standard: String?; var byColor: [Int: String] }

    /// Product ID → its pictures, read once.
    private static let paths: [UInt16: Pictures] = {
        let fm = FileManager.default
        var entries: [UInt16: [String: Any]] = [:]
        for file in (try? fm.contentsOfDirectory(atPath: resources)) ?? []
        where file.hasPrefix("AssetPaths") && file.hasSuffix(".plist") {
            guard let data = fm.contents(atPath: resources + "/" + file),
                  let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { continue }
            for (key, value) in dict {
                guard let id = productID(key), let entry = value as? [String: Any], entries[id] == nil else { continue }
                entries[id] = entry
            }
        }
        func file(_ name: Any?) -> String? {
            guard let name = name as? String, !name.contains("/") else { return nil }
            let path = resources + "/" + name
            return fm.isReadableFile(atPath: path) ? path : nil
        }
        var result: [UInt16: Pictures] = [:]
        for id in entries.keys {
            var entry = entries[id]
            if let clone = (entry?["Clone"] as? String).flatMap(productID) { entry = entries[clone] }   // same picture as another model
            guard let entry, entry["Bundle"] == nil else { continue }
            var byColor: [Int: String] = [:]
            for (key, name) in entry["Color"] as? [String: Any] ?? [:] {
                if let color = productID(key), let path = file(name) { byColor[Int(color)] = path }
            }
            let pictures = Pictures(standard: file(entry["ImageName"]), byColor: byColor)
            if pictures.standard != nil || !byColor.isEmpty { result[id] = pictures }
        }
        return result
    }()

    private static func productID(_ key: String) -> UInt16? {
        let hex = key.lowercased()
        return hex.hasPrefix("0x") ? UInt16(hex.dropFirst(2), radix: 16) : nil
    }

    /// Magic Mouse 1, 2 and the USB-C one.
    static let magicMice: Set<UInt16> = [0x030D, 0x0269, 0x0323]

    /// The file of the model's picture, if this Mac has one: in the device's colour where it reports one (the
    /// Magic Mouse does, see `BluetoothMonitor`). Only headphones (product IDs 0x2000…) and the Magic Mouse, not
    /// iPhones etc.
    static func path(forProductID id: UInt16?, color: Int? = nil) -> String? {
        guard let id, (0x2000...0x20FF).contains(id) || magicMice.contains(id), let pictures = paths[id] else { return nil }
        return color.flatMap { pictures.byColor[$0] } ?? pictures.standard ?? pictures.byColor.values.sorted().first
    }

    private static let cache = NSCache<NSString, NSImage>()

    /// The picture itself, cached.
    static func image(at path: String) -> NSImage? {
        if let image = cache.object(forKey: path as NSString) { return image }
        guard let image = NSImage(contentsOfFile: path) else { return nil }
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}
