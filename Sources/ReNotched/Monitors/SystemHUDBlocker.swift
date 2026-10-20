import AppKit

/// Optionally keeps macOS's own volume overlay from appearing, so that only the island animates.
///
/// The overlay is drawn by a system helper, `OSDUIHelper`, which macOS starts on demand when a volume key is
/// pressed. While blocking is on, the helper is suspended (SIGSTOP) as soon as it appears. When blocking stops
/// (switched off, app quits, or the built-in display is no longer the main display) the helper is ended
/// instead of resumed, so nothing that piled up in the meantime flashes up; macOS starts a fresh one when needed.
///
/// No permissions are involved, only signals to a process of the same user. Brightness and keyboard-backlight
/// overlays come from the same helper and are hidden as well. If the app is force-quit while blocking, the
/// helper stays suspended until the next login or `killall -9 OSDUIHelper`.
@MainActor
final class SystemHUDBlocker {
    private static let helperID = "com.apple.OSDUIHelper"
    private var enabled = false
    private var suspended: Set<pid_t> = []
    private var observation: NSKeyValueObservation?

    func setEnabled(_ on: Bool) {
        enabled = on
        if on, observation == nil {
            observation = NSWorkspace.shared.observe(\.runningApplications) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        } else if !on {
            observation = nil
        }
        refresh()
    }

    /// Blocks only while the built-in display (with the island) is the main display, i.e. where the overlay appears.
    private var shouldBlock: Bool { enabled && NSScreen.screens.first?.isBuiltIn == true }

    func refresh() {
        let helpers = NSRunningApplication.runningApplications(withBundleIdentifier: Self.helperID)
        if shouldBlock {
            for helper in helpers where !suspended.contains(helper.processIdentifier) {
                if kill(helper.processIdentifier, SIGSTOP) == 0 { suspended.insert(helper.processIdentifier) }
            }
        } else {
            releaseAll()
        }
    }

    func releaseAll() {
        let alive = Set(NSRunningApplication.runningApplications(withBundleIdentifier: Self.helperID).map(\.processIdentifier))
        for pid in suspended where alive.contains(pid) { kill(pid, SIGKILL) }   // pid reuse is ruled out by the check above
        suspended.removeAll()
    }
}
