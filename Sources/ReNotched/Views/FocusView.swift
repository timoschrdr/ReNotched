import SwiftUI

/// Focus turned on or off, shown around the notch: the mode's icon on the left, its state on the right.
/// The island first shows the previous state, then switches over: turning on fills the icon with the mode's
/// colour, lifts the slash and sends a ripple out; turning off drains the colour and draws the slash across.
struct FocusContent: View {
    @ObservedObject var model: IslandModel
    @State private var appeared = false
    @State private var shownOn: Bool?          // the state on screen; nil until the view appears
    @State private var ripple = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let (symbol, tint, on): (String, Color, Bool) = {
            if case let .focus(s, t, o)? = model.transient { return (s, Self.color(named: t), o) }
            return ("moon.fill", .indigo, false)
        }()
        let lit = shownOn ?? !on

        SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
            ZStack {
                Circle().stroke(tint, lineWidth: 2)                       // ripple when Focus turns on
                    .scaleEffect(ripple ? 2.4 : 0.8).opacity(ripple ? 0 : (lit ? 0.8 : 0))
                Circle().fill(lit ? tint : Color.white.opacity(0.18))
                    .shadow(color: lit ? tint.opacity(0.7) : .clear, radius: 7)
                    .scaleEffect(appeared ? 1 : 0.3)
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(lit ? 1 : 0.55))
                    .symbolEffect(.bounce, options: .nonRepeating, value: lit)
                    .scaleEffect(appeared ? 1 : 0.2)
                Slash().trim(from: 0, to: lit ? 0 : 1)                    // drawn across while off
                    .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 15, height: 15)
            }
            .frame(width: 26, height: 26)
        } right: {
            Text(lit ? "On" : "Off")
                .font(.system(size: 12, weight: .semibold))
                .contentTransition(.interpolate)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(lit ? tint : Color.white.opacity(0.18), in: Capsule())
                .foregroundStyle(.white)
                .offset(x: appeared ? 0 : 16).opacity(appeared ? 1 : 0)
        }
        .onAppear {
            if reduceMotion { shownOn = on; appeared = true; return }
            shownOn = !on                                             // start from the previous state
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
            switchOver(to: on, after: 0.45)
        }
        .onChange(of: on) { switchOver(to: on, after: 0) }        // toggled again while visible
    }

    private func switchOver(to on: Bool, after delay: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { shownOn = on }
            guard on, !reduceMotion else { return }
            ripple = false
            withAnimation(.easeOut(duration: 0.7)) { ripple = true }
        }
    }

    /// Maps the system's colour names (as used in the Focus configuration) to SwiftUI colours.
    private static func color(named name: String) -> Color {
        switch name {
        case "systemBlueColor": .blue
        case "systemPurpleColor": .purple
        case "systemGreenColor": .green
        case "systemTealColor": .teal
        case "systemOrangeColor": .orange
        case "systemPinkColor": .pink
        case "systemRedColor": .red
        case "systemYellowColor": .yellow
        case "systemCyanColor": .cyan
        case "systemMintColor": .mint
        default: .indigo
        }
    }
}

private struct Slash: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}
