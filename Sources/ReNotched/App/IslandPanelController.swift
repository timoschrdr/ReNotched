import AppKit
import Combine
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Owns the borderless panel over the notch: placement on the built-in display, click handling and
/// hiding while an app is in fullscreen.
@MainActor
final class IslandPanelController {
    private let model: IslandModel
    private let panel: NotchPanel
    private let panelSize = CGSize(width: 440, height: 190)
    private var cancellable: AnyCancellable?
    private var eventMonitors: [Any] = []
    private var spaceWatch: Task<Void, Never>?

    init(model: IslandModel, actions: MusicActions) {
        self.model = model
        panel = NotchPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                           backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)   // above the menu bar
        panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]                   // no fullscreen spaces
        panel.ignoresMouseEvents = true
        panel.isMovable = false

        let host = NSHostingView(rootView: IslandView(model: model, actions: actions))
        host.sizingOptions = []
        panel.contentView = host
    }

    func start() {
        reposition()
        watchSpaces()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.watchSpaces() }
            }
        }

        // Clicks: expand the compact island, collapse the expanded one.
        let handler: (NSEvent) -> Void = { [weak self] _ in MainActor.assumeIsolated { self?.clicked() } }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: handler) { eventMonitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { e in handler(e); return e }) { eventMonitors.append(m) }

        // The panel only takes mouse events while the expanded player is open.
        cancellable = model.$mode.removeDuplicates().sink { [weak self] mode in
            self?.panel.ignoresMouseEvents = mode != .musicExpanded
        }
    }

    // MARK: Placement

    /// The island lives on the built-in display only, never on external monitors.
    private var builtIn: (screen: NSScreen, id: CGDirectDisplayID)? {
        for screen in NSScreen.screens {
            if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               CGDisplayIsBuiltin(id) != 0 { return (screen, id) }
        }
        return nil
    }

    private func reposition() {
        guard let screen = builtIn?.screen else { panel.orderOut(nil); return }   // e.g. lid closed
        var size = CGSize(width: 190, height: 32)   // fallback for screens without a notch
        if screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            size = CGSize(width: screen.frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
        }
        model.notch = size
        let f = screen.frame
        panel.setFrame(NSRect(x: f.midX - panelSize.width / 2, y: f.maxY - panelSize.height,
                              width: panelSize.width, height: panelSize.height), display: true)
        if !model.hidden { panel.orderFrontRegardless() }
    }

    // MARK: Fullscreen

    /// After a space change, polls for a moment: the fullscreen state can lag and even flip back for about a
    /// second after the notification. The island hides at the first sign of fullscreen and only returns once
    /// the display has been out of fullscreen for 1.6 s, so such a flicker cannot make it flash up in between.
    private func watchSpaces() {
        spaceWatch?.cancel()
        spaceWatch = Task { [weak self] in
            var calm = 0   // consecutive polls without fullscreen
            for _ in 0..<70 {
                guard let self, !Task.isCancelled else { return }
                if let id = self.builtIn?.id, Spaces.isFullscreen(display: id) {
                    calm = 0
                    if !self.model.hidden { self.model.setHidden(true); self.panel.orderOut(nil) }
                } else {
                    calm += 1
                    if self.model.hidden && calm >= 20 {            // 1.6 s out of fullscreen
                        self.model.setHidden(false)
                        if self.builtIn != nil { self.panel.orderFrontRegardless() }
                    } else if !self.model.hidden && calm >= 25 {     // nothing happened for 2 s
                        return
                    }
                }
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    // MARK: Clicks

    private func clicked() {
        let size = model.currentSize
        let f = panel.frame
        let island = NSRect(x: f.midX - size.width / 2, y: f.maxY - size.height, width: size.width, height: size.height)
            .insetBy(dx: -4, dy: -4)
        let inside = island.contains(NSEvent.mouseLocation)
        switch model.mode {
        case .musicCompact where inside: model.setExpanded(true)
        case .musicExpanded where !inside: model.setExpanded(false)
        default: break
        }
    }
}
