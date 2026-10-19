import ServiceManagement
import SwiftUI

enum Pref {
    static let volume = "showVolume", copy = "showCopy", power = "showPower", device = "showDevice", focus = "showFocus"
    /// Every indicator is on by default, except Focus, which needs Full Disk Access.
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
            Text(title)
            Spacer()
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }
}

struct SettingsView: View {
    /// Whether the Focus database can be read (Full Disk Access granted).
    let focusAvailable: () -> Bool
    @State private var focusReadable = true
    @AppStorage(Pref.focus) private var focus = false
    @AppStorage(Pref.volume) private var volume = true
    @AppStorage(Pref.copy) private var copy = true
    @AppStorage(Pref.power) private var power = true
    @AppStorage(Pref.device) private var device = true
    @State private var login = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ReNotched.").font(.title2.weight(.semibold))
                    Text("Your notch as a Dynamic Island").foregroundStyle(.secondary)
                }
            }
            .padding(.top, 12)

            Text("Manage island animations").font(.headline).padding(.horizontal, 6).padding(.bottom, -8)
            VStack(spacing: 0) {
                Row(symbol: "speaker.wave.2.fill", color: .blue, title: "Volume", isOn: $volume)
                Row(symbol: "doc.on.doc.fill", color: .orange, title: "Copying", isOn: $copy)
                Row(symbol: "bolt.fill", color: .green, title: "Charger", isOn: $power)
                Row(symbol: "headphones", color: .purple, title: "Headphones connected", isOn: $device)
                Row(symbol: "moon.fill", color: .indigo, title: "Focus", isOn: $focus)
            }
            .padding(.vertical, 4).card()

            if focus && !focusReadable {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("Focus needs Full Disk Access. Allow ReNotched. in System Settings, then reopen the app.")
                        .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Open") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                    }.buttonStyle(.glass).controlSize(.small)
                }
                .padding(.horizontal, 6)
            }

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
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).padding(.bottom, 20)
        .frame(width: 400, height: focus && !focusReadable ? 640 : 570)
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
