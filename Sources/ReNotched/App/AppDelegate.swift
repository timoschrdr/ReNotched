import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = IslandModel()
    private lazy var music = NowPlayingMonitor(model: model)
    private lazy var panel = IslandPanelController(
        model: model,
        actions: MusicActions(playPause: { [weak self] in self?.music.playPause() },
                              next: { [weak self] in self?.music.next() },
                              previous: { [weak self] in self?.music.previous() },
                              seek: { [weak self] in self?.music.seek(to: $0) }))
    private let volume = VolumeMonitor()
    private let clipboard = ClipboardMonitor()
    private let power = PowerMonitor()
    private let bluetooth = BluetoothMonitor()
    private let focus = FocusMonitor()
    private let systemHUD = SystemHUDBlocker()
    private var settingsWindow: NSWindow?
    private var termSource: DispatchSourceSignal?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel.start()
        setupMenu()
        // Started by "Launch at login": stay in the background instead of opening the settings.
        if SMAppService.mainApp.status == .enabled && ProcessInfo.processInfo.systemUptime < 180 {
            NSApp.setActivationPolicy(.accessory)
        } else {
            showSettings()
        }
        connectMonitors()
        music.start()
        quitCleanlyOnSIGTERM()
    }

    /// Makes `kill` and logout stop the helper process too, instead of leaving it behind.
    private func quitCleanlyOnSIGTERM() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { NSApp.terminate(nil) }
        source.resume()
        termSource = source
    }

    func applicationWillTerminate(_ notification: Notification) {
        music.stop()
        systemHUD.releaseAll()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    // MARK: Monitors

    /// Shows an event on the island unless the user switched that indicator off in the settings.
    private func show(_ pref: String, _ event: Transient, for seconds: Double) {
        if Pref.on(pref) { model.show(event, for: seconds) }
    }

    private func connectMonitors() {
        volume.onChange = { [weak self] level, muted in self?.show(Pref.volume, .volume(level: level, muted: muted), for: 1.6) }
        volume.onBluetoothOutput = { [weak self] name in self?.bluetooth.announce(name: name) }
        volume.start()

        clipboard.onCopy = { [weak self] preview, symbol in self?.show(Pref.copy, .copied(preview: preview, symbol: symbol), for: 2.2) }
        clipboard.start()

        power.onChange = { [weak self] percent, plugged in self?.show(Pref.power, .charging(percent: percent, plugged: plugged), for: 2.2) }
        power.start()

        bluetooth.onConnect = { [weak self] name, battery in self?.show(Pref.device, .device(name: name, battery: battery), for: 3) }
        bluetooth.start()

        var lastFocus = FocusMonitor.State(id: "", name: "", symbol: "moon.fill", tint: "systemIndigoColor")
        focus.onChange = { [weak self] state in
            if let state { lastFocus = state }
            self?.show(Pref.focus, .focus(symbol: lastFocus.symbol, tint: lastFocus.tint, on: state != nil), for: 2.4)
        }
        if Pref.on(Pref.focus) { focus.start() }

        systemHUD.setEnabled(Pref.on(Pref.hideSystemHUD))
        NotificationCenter.default.addObserver(forName: .hideSystemHUDPreferenceChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.systemHUD.setEnabled(Pref.on(Pref.hideSystemHUD)) }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.systemHUD.refresh() }
        }
        NotificationCenter.default.addObserver(forName: .focusPreferenceChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { Pref.on(Pref.focus) ? self?.focus.start() : self?.focus.stop() }
        }
    }

    // MARK: Menu and settings window

    private func setupMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        main.addItem(appItem)
        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("Settings…", comment: ""), action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: NSLocalizedString("Hide ReNotched.", comment: ""), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(withTitle: NSLocalizedString("Quit ReNotched.", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = menu
        NSApp.mainMenu = main
    }

    /// Opening the app again (Finder, Spotlight, Dock) brings the settings window back, with its power button.
    @objc private func showSettings() {
        NSApp.setActivationPolicy(.regular)   // Dock icon and menu bar while the window is open
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(focusAvailable: { [focus] in focus.isAvailable })))
            window.title = "ReNotched."
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.toolbarStyle = .unified
            window.isReleasedWhenClosed = false
            window.center()
            // Closing the window leaves the app running in the background without a Dock icon.
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { _ in
                _ = MainActor.assumeIsolated { NSApp.setActivationPolicy(.accessory) }
            }
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
