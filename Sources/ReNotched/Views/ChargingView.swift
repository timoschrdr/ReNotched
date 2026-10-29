import SwiftUI

// MARK: - Charging

/// Charger plugged in or removed: a battery filled to the exact charge on the left (with a bolt inside while
/// charging, like the macOS menu bar), the percentage on the right.
struct ChargingContent: View {
    @ObservedObject var model: IslandModel
    @State private var appeared = false

    var body: some View {
        let (percent, plugged): (Int, Bool) = {
            if case let .charging(p, c)? = model.transient { return (p, c) }
            return (0, false)
        }()
        SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
            BatteryGlyph(level: appeared ? Double(percent) / 100 : 0, charging: plugged)
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
        } right: {
            Text("\(percent)%").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(.white)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { appeared = true } }
    }
}

/// The battery exactly as macOS draws it in the menu bar, from SF Symbols (`battery.100percent`, with `.bolt`
/// while charging). The symbol has no level of its own, so it is drawn twice: translucent for the empty part and
/// solid, masked to the exact charge, for the charged part. Yellow in Low Power Mode, like macOS and iOS
/// (it often switches on just after the charger is removed, so the colour follows it live), otherwise red at 10 %
/// or less on battery.
struct BatteryGlyph: View {
    let level: Double
    let charging: Bool
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var symbol: String { charging ? "battery.100percent.bolt" : "battery.100percent" }
    private var fillColor: Color { lowPower ? .yellow : !charging && level <= 0.1 ? .red : .white }

    var body: some View {
        let glyph = Image(systemName: symbol).font(.system(size: 19, weight: .regular))
        ZStack(alignment: .leading) {
            glyph.foregroundStyle(.white.opacity(0.35))
            glyph.foregroundStyle(fillColor)
                .mask(alignment: .leading) {
                    GeometryReader { g in
                        // the body takes up about the first 88 % of the symbol, the cap the rest
                        Rectangle().frame(width: g.size.width * (0.04 + 0.84 * min(max(level, 0), 1)))
                    }
                }
        }
        .contentTransition(.symbolEffect(.replace))
        .animation(.spring(response: 0.7, dampingFraction: 0.85), value: level)
        .animation(.easeInOut(duration: 0.3), value: charging)
        .animation(.easeInOut(duration: 0.3), value: lowPower)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: RunLoop.main)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}
