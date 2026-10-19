import AppKit

// Private CoreGraphics (SkyLight) calls, read-only. If they ever disappear, `isFullscreen` simply returns false.
@_silgen_name("CGSMainConnectionID") private func CGSMainConnectionID() -> Int32
@_silgen_name("CGSCopyManagedDisplaySpaces") private func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray

enum Spaces {
    /// True while the active space of the given display is a fullscreen space (type 4), e.g. an app in fullscreen.
    static func isFullscreen(display id: CGDirectDisplayID) -> Bool {
        let uuid = CFUUIDCreateString(nil, CGDisplayCreateUUIDFromDisplayID(id).takeRetainedValue()) as String
        let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: Any]] ?? []
        guard let display = displays.first(where: { ($0["Display Identifier"] as? String)?.caseInsensitiveCompare(uuid) == .orderedSame }),
              let current = display["Current Space"] as? [String: Any] else { return false }
        return (current["type"] as? Int) == 4
    }
}
