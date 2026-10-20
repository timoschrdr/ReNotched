import ServiceManagement
import SwiftUI

enum Pref {
    static let volume = "showVolume", copy = "showCopy", power = "showPower", device = "showDevice", focus = "showFocus"
    /// Everything is on by default, except Focus, which needs Full Disk Access.
    static func on(_ key: String) -> Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? (key != focus) }
}

extension Notification.Name {
    static let focusPreferenceChanged = Notification.Name("ReNotched.focusPreferenceChanged")
}

private extension View {
    /// Liquid Glass card.
    func card(_ radius: CGFloat = 22) -> some View {
        glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

private struct Row: View {
    let symbol: String, color: Color, title: LocalizedStringKey
    var subtitle: LocalizedStringKey? = nil
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil
    var disabled = false
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                // Like System Settings: coloured tile with white glyph in light mode, black tile with coloured glyph in dark mode
                .foregroundStyle(scheme == .dark ? color : .white)
                .frame(width: 30, height: 30)
                .background(scheme == .dark ? AnyShapeStyle(Color.black) : AnyShapeStyle(color.gradient),
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(.white.opacity(scheme == .dark ? 0.12 : 0), lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            if let actionTitle, let action { Button(actionTitle, action: action).buttonStyle(.glass).controlSize(.small) }
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch).disabled(disabled)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }
}

private struct IconTile: View {
    let choice: AppIconChoice
    let selected: Bool
    let dark: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(nsImage: choice.image(dark: dark)).resizable().frame(width: 72, height: 72)
                Text(choice.title).font(.caption.weight(selected ? .semibold : .regular))
            }
            .padding(10)
            .background(selected ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(.clear), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.tint, lineWidth: selected ? 2 : 0))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct SettingsView: View {
    /// Whether the Focus database can be read (Full Disk Access granted).
    let focusAvailable: () -> Bool
    @State private var focusReadable: Bool
    @AppStorage(Pref.focus) private var focus = false
    @AppStorage(AppIconChoice.preferenceKey) private var appIcon = AppIconChoice.penguin.rawValue
    @Environment(\.colorScheme) private var scheme
    @AppStorage(Pref.volume) private var volume = true
    @AppStorage(Pref.copy) private var copy = true
    @AppStorage(Pref.power) private var power = true
    @AppStorage(Pref.device) private var device = true
    @State private var login = SMAppService.mainApp.status == .enabled

    init(focusAvailable: @escaping () -> Bool) {
        self.focusAvailable = focusAvailable
        _focusReadable = State(initialValue: focusAvailable())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: (AppIconChoice(rawValue: appIcon) ?? .penguin).image(dark: scheme == .dark)).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ReNotched.").font(.title2.weight(.semibold))
                    Text("Your notch as a Dynamic Island").foregroundStyle(.secondary)
                }
            }
            .padding(.top, 12)

            Text("Manage island animations").font(.headline).padding(.horizontal, 6).padding(.bottom, -8)
            VStack(spacing: 0) {
                Row(symbol: "speaker.wave.2.fill", color: .blue, title: "Volume", subtitle: "Level and mute when you change it", isOn: $volume)
                Row(symbol: "doc.on.doc.fill", color: .orange, title: "Copying", subtitle: "A preview of what you copy", isOn: $copy)
                Row(symbol: "bolt.fill", color: .green, title: "Charger", subtitle: "Battery level when you plug in or unplug", isOn: $power)
                Row(symbol: "headphones", color: .purple, title: "Headphones", subtitle: "Name and battery when they connect", isOn: $device)
                // The caption is always there, so the layout never changes when access is granted or missing.
                // Greyed out until Full Disk Access is granted; the caption says why.
                Row(symbol: "moon.fill", color: .indigo, title: "Focus", subtitle: "Needs Full Disk Access",
                    actionTitle: focusReadable ? nil : "Open",
                    action: { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!) },
                    disabled: !focusReadable,
                    isOn: Binding(get: { focus && focusReadable }, set: { focus = $0 }))
            }
            .padding(.vertical, 4).card()

            Text("App icon").font(.headline).padding(.horizontal, 6).padding(.bottom, -8)
            HStack(spacing: 14) {
                ForEach(AppIconChoice.allCases) { choice in
                    IconTile(choice: choice, selected: appIcon == choice.rawValue, dark: scheme == .dark) { appIcon = choice.rawValue }
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12).card()
            .onChange(of: appIcon) { NotificationCenter.default.post(name: .appIconPreferenceChanged, object: nil) }

            Row(symbol: "power", color: .gray, title: "Launch at login", isOn: $login)
                .card()
                .onChange(of: login) { _, on in
                    do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } }
                    catch { login = SMAppService.mainApp.status == .enabled }
                }

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.shield.fill").font(.system(size: 18)).foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Privacy").font(.subheadline.weight(.semibold))
                    Text("ReNotched. works entirely on your Mac. It collects, stores and sends no data and has no network access. Clipboard text, now-playing info and Bluetooth device names are only read to show them on the island and are never saved.")
                        .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14).card()
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)   // the window fits its content; nothing in it changes height afterwards
        .onAppear { focusReadable = focusAvailable() }
        .onChange(of: focus) {
            focusReadable = focusAvailable()
            NotificationCenter.default.post(name: .focusPreferenceChanged, object: nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            focusReadable = focusAvailable()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { NSApp.terminate(nil) } label: { Label("Quit", systemImage: "power") }
                    .help("Quit ReNotched.")
            }
        }
    }
}
