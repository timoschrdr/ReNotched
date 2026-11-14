// Renders docs/screenshot.png from the app's real views over a neutral backdrop (no screen content, no real songs).
// Compiled together with the app's sources by Tools/make-screenshot.sh, which also captures the window.
import AppKit
import SwiftUI

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
ChargingContent.lowPowerOverride = false

/// A made-up cover: a warm gradient with a ring.
let cover: NSImage = {
    let size = NSSize(width: 160, height: 160)
    return NSImage(size: size, flipped: false) { r in
        NSGradient(colors: [NSColor(red: 0.95, green: 0.33, blue: 0.40, alpha: 1),
                            NSColor(red: 0.97, green: 0.60, blue: 0.25, alpha: 1)])?.draw(in: r, angle: -45)
        NSColor.white.withAlphaComponent(0.35).setFill()
        NSBezierPath(ovalIn: r.insetBy(dx: 38, dy: 38)).fill()
        NSColor.white.withAlphaComponent(0.6).setFill()
        NSBezierPath(ovalIn: r.insetBy(dx: 66, dy: 66)).fill()
        return true
    }
}()

@MainActor func model(_ setup: (IslandModel) -> Void) -> IslandModel {
    let m = IslandModel()
    m.notch = CGSize(width: 185, height: 32)
    m.notchExtra = 1
    setup(m)
    return m
}

@MainActor func playing(expanded: Bool) -> IslandModel {
    model { m in
        var t = Track(title: "Example Song", artist: "Example Artist")
        t.artwork = cover; t.artID = 1; t.duration = 214
        t.tint = Color(red: 1, green: 0.32, blue: 0.38)
        m.track = t
        m.isPlaying = true
        m.position = 89; m.positionDate = Date(); m.rate = 0   // rate 0: the time stands still
        m.setExpanded(expanded)
    }
}

@MainActor func event(_ e: Transient) -> IslandModel { model { $0.show(e, for: 1e6) } }

let noActions = MusicActions(playPause: {}, next: {}, previous: {}, seek: { _ in })

struct Tile: View {
    let title: String
    let model: IslandModel
    let height: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.31, green: 0.45, blue: 0.84), Color(red: 0.51, green: 0.32, blue: 0.78)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Color.black.opacity(0.22).frame(height: model.notch.height + model.notchExtra)   // the menu bar
            IslandView(model: model, actions: noActions)
            VStack { Spacer(); Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.92)).padding(.bottom, 14) }
        }
        .frame(width: 440, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct Sheet: View {
    let tiles: [(String, IslandModel, CGFloat)]
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 16) { ForEach(0..<3) { i in Tile(title: tiles[i].0, model: tiles[i].1, height: tiles[i].2) } }
            VStack(spacing: 16) { ForEach(3..<7) { i in Tile(title: tiles[i].0, model: tiles[i].1, height: tiles[i].2) } }
        }
        .padding(24)
        .background(Color(red: 0.11, green: 0.12, blue: 0.15))
        .environment(\.locale, Locale(identifier: "en"))
    }
}

MainActor.assumeIsolated {
    let tiles: [(String, IslandModel, CGFloat)] = [
        ("Now playing – click to expand", playing(expanded: true), 235),
        ("Now playing – compact", playing(expanded: false), 100),
        ("Charger", event(.charging(percent: 82, plugged: true)), 100),
        // the right column has one more tile, but ends level with the left one
        ("Volume", event(.volume(level: 0.6, muted: false, symbol: nil)), 104.75),
        ("Focus", event(.focus(symbol: "moon.fill", tint: "systemIndigoColor", on: true)), 104.75),
        ("AirPods connected", event(.device(name: "AirPods Pro", battery: 72, symbol: "airpods.pro")), 104.75),
        ("Copying", event(.copied(preview: "Hello from ReNotched.", symbol: "text.alignleft")), 104.75),
    ]
    let host = NSHostingView(rootView: Sheet(tiles: tiles))
    let size = host.fittingSize
    let window = NSWindow(contentRect: NSRect(origin: NSPoint(x: 80, y: 80), size: size), styleMask: .borderless, backing: .buffered, defer: false)
    window.contentView = host
    window.level = .floating
    window.orderFrontRegardless()
    // Let the appear animations settle, then hand the window number to the script
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
        print(window.windowNumber); fflush(stdout)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { exit(0) }
    }
}
app.run()
