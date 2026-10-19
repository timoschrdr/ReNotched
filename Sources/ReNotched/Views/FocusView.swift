import SwiftUI

/// Focus turned on or off, shown around the notch: the mode's icon on the left, its state on the right.
/// "On" fills the icon with the mode's colour and sends a ripple out; "Off" drains the colour and slashes the icon.
struct FocusContent: View {
    @ObservedObject var model: IslandModel
    @State private var appeared = false

    var body: some View {
        let (symbol, tint, on): (String, Color, Bool) = {
            if case let .focus(s, t, o)? = model.transient { return (s, Self.color(named: t), o) }
            return ("moon.fill", .indigo, false)
        }()

        SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
            ZStack {
                Circle().stroke(tint, lineWidth: 2)                       // ripple, only visible while appearing
                    .scaleEffect(appeared ? 2.4 : 0.8).opacity(appeared || !on ? 0 : 0.8)
                Circle().fill(on ? tint : Color.white.opacity(0.18))
                    .shadow(color: on ? tint.opacity(0.7) : .clear, radius: 7)
                    .scaleEffect(appeared ? 1 : 0.3)
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(on ? 1 : 0.55))
                    .symbolEffect(.bounce, options: .nonRepeating, value: appeared)
                    .scaleEffect(appeared ? 1 : 0.2)
                Slash().trim(from: 0, to: !on && appeared ? 1 : 0)       // draws across when turned off
                    .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 15, height: 15)
            }
            .frame(width: 26, height: 26)
        } right: {
            Text(on ? "On" : "Off")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(on ? tint : Color.white.opacity(0.18), in: Capsule())
                .foregroundStyle(.white)
                .offset(x: appeared ? 0 : 16).opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { appeared = true }
        }
        .animation(.easeOut(duration: 0.5), value: appeared)
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
