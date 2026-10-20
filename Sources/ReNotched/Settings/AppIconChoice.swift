import AppKit
import SwiftUI

/// The icons the user can choose between in the settings. The default (the penguin) is the app's own bundle icon;
/// the alternative ones ship as ready-made images and are set as the Dock icon at runtime.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case penguin, island

    static let preferenceKey = "appIcon"
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .penguin: "Penguin"
        case .island: "Island"
        }
    }

    /// The icon for light or dark appearance.
    func image(dark: Bool) -> NSImage {
        switch self {
        case .penguin:
            return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        case .island:
            let name = dark ? "IslandIcon-dark" : "IslandIcon-light"
            return Bundle.main.url(forResource: name, withExtension: "png").flatMap { NSImage(contentsOf: $0) }
                ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        }
    }

    static var current: AppIconChoice {
        AppIconChoice(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .penguin
    }
}

extension Notification.Name {
    static let appIconPreferenceChanged = Notification.Name("ReNotched.appIconPreferenceChanged")
}
