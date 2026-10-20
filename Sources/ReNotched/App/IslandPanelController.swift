import AppKit
import Combine
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Owns the borderless panel over the notch: placement on the built-in display and click handling.
///
/// The panel belongs to one desktop space (`.moveToActiveSpace`) instead of all spaces. A window on all spaces
/// is also drawn for a frame or two when a fullscreen space becomes active; a window that lives on a desktop
/// space is simply not part of the fullscreen space, so the island slides away with the desktop. After a space
/// change it is moved to the new desktop, unless that space is a fullscreen one.
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
        panel.collectionBehavior = [.moveToActiveSpace, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.isMovable = false

        let host = NSHostingView(rootView: IslandView(model: model, actions: actions))
        host.sizingOptions = []
        panel.contentView = host
    }

    func start() {
        reposition()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.watchSpaces() }
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
        // The menu bar is as tall as the notch's lower edge; use it (within sane limits) to size the active island.
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        model.notchExtra = (menuBar > size.height && menuBar - size.height <= 4) ? menuBar - size.height : 1
        let f = screen.frame
        panel.setFrame(NSRect(x: f.midX - panelSize.width / 2, y: f.maxY - panelSize.height,
                              width: panelSize.width, height: panelSize.height), display: true)
        moveToActiveDesktop()
    }

    // MARK: Spaces

    private var isFullscreen: Bool {
        guard let id = builtIn?.id else { return false }
        return Spaces.isFullscreen(display: id)
    }

    /// Brings the island to the current desktop, but never into a fullscreen space.
    private func moveToActiveDesktop() {
        if builtIn != nil, !isFullscreen { panel.orderFrontRegardless() }
    }

    /// The fullscreen state of a new space can lag behind the notification, so poll briefly and move the
    /// island once the space has been a normal desktop for 0.3 s.
    private func watchSpaces() {
        spaceWatch?.cancel()
        spaceWatch = Task { [weak self] in
            var calm = 0
            for _ in 0..<25 {
                guard let self, !Task.isCancelled else { return }
                if self.isFullscreen { return }          // nothing to do: the island stays on its desktop
                calm += 1
                if calm >= 4 { self.moveToActiveDesktop(); return }
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
