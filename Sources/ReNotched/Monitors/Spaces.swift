import AppKit

/// Private CoreGraphics (SkyLight) calls, read-only. They are looked up at runtime, so if a future macOS removes
/// them the app still starts and `isFullscreen` simply returns false.
enum Spaces {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias CopySpaces = @convention(c) (Int32) -> Unmanaged<CFArray>?

    private static let calls: (connection: MainConnection, copy: CopySpaces)? = {
        let handle = UnsafeMutableRawPointer(bitPattern: -2)   // RTLD_DEFAULT
        guard let c = dlsym(handle, "CGSMainConnectionID"), let s = dlsym(handle, "CGSCopyManagedDisplaySpaces") else { return nil }
        return (unsafeBitCast(c, to: MainConnection.self), unsafeBitCast(s, to: CopySpaces.self))
    }()

    /// True while the active space of the given display is a fullscreen space (type 4), e.g. an app in fullscreen.
    static func isFullscreen(display id: CGDirectDisplayID) -> Bool {
        guard let calls, let cfUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let displays = calls.copy(calls.connection())?.takeRetainedValue() as? [[String: Any]] else { return false }
        let uuid = CFUUIDCreateString(nil, cfUUID) as String
        // With "Displays have separate Spaces" switched off there is a single entry called "Main"
        let display = displays.first { ($0["Display Identifier"] as? String)?.caseInsensitiveCompare(uuid) == .orderedSame }
            ?? (displays.count == 1 ? displays[0] : nil)
        guard let current = display?["Current Space"] as? [String: Any] else { return false }
        return (current["type"] as? Int) == 4
    }
}
