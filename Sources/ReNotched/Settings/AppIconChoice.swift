import AppKit
import SwiftUI

/// The icons the user can choose between in the settings. The default one is the app's own bundle icon; the
/// alternative ones ship as ready-made images and are set as the Dock icon at runtime.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case standard, penguin

    static let preferenceKey = "appIcon"
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .standard: "Default"
        case .penguin: "Penguin"
        }
    }

    /// The icon for light or dark appearance.
    func image(dark: Bool) -> NSImage {
        switch self {
        case .standard:
            return NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        case .penguin:
            let name = dark ? "PenguinIcon-dark" : "PenguinIcon-light"
            return Bundle.main.url(forResource: name, withExtension: "png").flatMap { NSImage(contentsOf: $0) }
                ?? NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath)
        }
    }

    static var current: AppIconChoice {
        AppIconChoice(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .standard
    }
}

extension Notification.Name {
    static let appIconPreferenceChanged = Notification.Name("ReNotched.appIconPreferenceChanged")
}
