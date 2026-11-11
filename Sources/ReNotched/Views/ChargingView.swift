import SwiftUI

// MARK: - Charging

/// Charger plugged in or removed: a battery filled to the exact charge on the left (with a bolt inside while
/// charging, like the macOS menu bar), the percentage on the right, both in the battery's colour like on the iPhone.
struct ChargingContent: View {
    @ObservedObject var model: IslandModel
    @State private var appeared = false
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    var body: some View {
        let (percent, plugged): (Int, Bool) = {
            if case let .charging(p, c)? = model.transient { return (p, c) }
            return (0, false)
        }()
        SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
            BatteryGlyph(level: appeared ? Double(percent) / 100 : 0, charging: plugged,
                         color: BatteryGlyph.color(percent: percent, charging: plugged, lowPower: lowPower))
                .scaleEffect(appeared ? 1 : 0.6)
                .opacity(appeared ? 1 : 0)
        } right: {
            Text("\(percent)%").font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(BatteryGlyph.color(percent: percent, charging: plugged, lowPower: lowPower))
                .animation(.easeInOut(duration: 0.3), value: lowPower)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { appeared = true } }
        // Low Power Mode often switches on just after the charger is removed, so the colour follows it live
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange).receive(on: RunLoop.main)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

/// The battery exactly as macOS draws it in the menu bar, from SF Symbols (`battery.100percent`, with `.bolt`
/// while charging). The symbol has no level of its own, so it is drawn twice: translucent for the empty part and
/// solid, masked to the exact charge, for the charged part. Coloured like on the iPhone: yellow in Low Power Mode,
/// green while charging, red at 20 % or less on battery, otherwise white.
struct BatteryGlyph: View {
    let level: Double
    let charging: Bool
    /// From the real charge, not the animated `level`, so the battery does not flash red while it fills up.
    let color: Color

    private var symbol: String { charging ? "battery.100percent.bolt" : "battery.100percent" }

    static func color(percent: Int, charging: Bool, lowPower: Bool) -> Color {
        lowPower ? .yellow : charging ? .green : percent <= 20 ? .red : .white
    }

    var body: some View {
        let glyph = Image(systemName: symbol).font(.system(size: 19, weight: .regular))
        ZStack(alignment: .leading) {
            glyph.foregroundStyle(.white.opacity(0.35))
            glyph.foregroundStyle(color)
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
        .animation(.easeInOut(duration: 0.3), value: color)
    }
}
