import AppKit
import Combine
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = IslandModel()
    private var panel: NotchPanel!
    private var music: NowPlayingMonitor!
    private let power = PowerMonitor()
    private let bluetooth = BluetoothMonitor()
    private let volume = VolumeMonitor()
    private let clipboard = ClipboardMonitor()
    private var settingsWindow: NSWindow?
    private var cancellable: AnyCancellable?
    private var monitors: [Any] = []

    private let panelSize = CGSize(width: 440, height: 190)

    func applicationDidFinishLaunching(_ notification: Notification) {
        music = NowPlayingMonitor(model: model)

        let actions = MusicActions(playPause: { [weak self] in self?.music.playPause() },
                                   next: { [weak self] in self?.music.next() },
                                   previous: { [weak self] in self?.music.previous() },
                                   seek: { [weak self] in self?.music.seek(to: $0) })
        setupPanel(actions: actions)
        setupMenu()
        showSettings()

        volume.onChange = { [weak self] level, muted in if Pref.on(Pref.volume) { self?.model.show(.volume(level: level, muted: muted), for: 1.6) } }
        volume.onBluetoothOutput = { [weak self] name in self?.bluetooth.announce(name: name) }
        volume.start()
        clipboard.onCopy = { [weak self] preview, symbol in if Pref.on(Pref.copy) { self?.model.show(.copied(preview: preview, symbol: symbol), for: 2.2) } }
        clipboard.start()
        power.onChange = { [weak self] percent, plugged in if Pref.on(Pref.power) { self?.model.show(.charging(percent: percent, plugged: plugged), for: 2.2) } }
        power.start()
        bluetooth.onConnect = { [weak self] name, battery in if Pref.on(Pref.device) { self?.model.show(.device(name: name, battery: battery), for: 3) } }
        bluetooth.start()
        music.start()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }

        let handler: (NSEvent) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.clicked() } }
        if let g = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: handler) { monitors.append(g) }
        if let l = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { e in handler(e); return e }) { monitors.append(l) }

        // Only accept clicks while the expanded music view is open.
        cancellable = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateClickThrough() }
        }
    }

    private func setupPanel(actions: MusicActions) {
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isMovable = false

        let host = NSHostingView(rootView: IslandView(model: model, actions: actions))
        host.sizingOptions = []
        panel.contentView = host
        reposition()
        panel.orderFrontRegardless()
    }

    private var notchScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }

    private func reposition() {
        guard let screen = notchScreen else { return }
        var size = CGSize(width: 190, height: 32) // fallback without a notch
        if screen.safeAreaInsets.top > 0,
           let l = screen.auxiliaryTopLeftArea, let r = screen.auxiliaryTopRightArea {
            size = CGSize(width: screen.frame.width - l.width - r.width, height: screen.safeAreaInsets.top)
        }
        model.notch = size
        let f = screen.frame
        panel.setFrame(NSRect(x: f.midX - panelSize.width / 2, y: f.maxY - panelSize.height,
                              width: panelSize.width, height: panelSize.height), display: true)
    }

    /// Clicking the compact island expands it; clicking elsewhere collapses it again.
    private func clicked() {
        let s = model.currentSize
        let f = panel.frame
        let rect = NSRect(x: f.midX - s.width / 2, y: f.maxY - s.height, width: s.width, height: s.height)
            .insetBy(dx: -4, dy: -4)
        let inside = rect.contains(NSEvent.mouseLocation)
        switch model.mode {
        case .musicCompact where inside: model.setExpanded(true)
        case .musicExpanded where !inside: model.setExpanded(false)
        default: break
        }
    }

    private func updateClickThrough() {
        panel.ignoresMouseEvents = model.mode != .musicExpanded
    }

    private func setupMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let menu = NSMenu()
        menu.addItem(withTitle: NSLocalizedString("Settings…", comment: ""), action: #selector(showSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: NSLocalizedString("Hide ReNotched.", comment: ""), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(withTitle: NSLocalizedString("Quit ReNotched.", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = menu
        NSApp.mainMenu = main
    }

    @objc private func showSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "ReNotched."
            w.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.toolbarStyle = .unified
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { music.stop() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
