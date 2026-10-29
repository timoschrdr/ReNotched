import SwiftUI

/// Focus turned on or off, like on the iPhone: the mode's icon on the left and "On" or "Off" on the right, both
/// in the mode's colour when on and grey when off – no boxes, no slash.
/// When the island appears, it shows the new state right away with a soft spring. If Focus changes again while
/// the island is still showing it, the colour fades over and the word blurs from one state into the other.
struct FocusContent: View {
    @ObservedObject var model: IslandModel
    @State private var appeared = false
    @State private var shownOn: Bool?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let off = Color(white: 0.55)

    var body: some View {
        let (symbol, tint, on): (String, Color, Bool) = {
            if case let .focus(s, t, o)? = model.transient { return (s, Self.color(named: t), o) }
            return ("moon.fill", .indigo, false)
        }()
        let lit = shownOn ?? on
        let color = lit ? tint : Self.off

        SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .symbolEffect(.bounce, options: .nonRepeating, value: appeared)
                .scaleEffect(appeared ? 1 : 0.4)
                .opacity(appeared ? 1 : 0)
        } right: {
            ZStack(alignment: .trailing) {
                Text(lit ? "On" : "Off")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(color)
                    .id(lit)
                    .transition(.blurReplace)
            }
            .scaleEffect(appeared ? 1 : 0.6, anchor: .trailing)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            shownOn = on
            if reduceMotion { appeared = true; return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { appeared = true }
        }
        .onChange(of: on) {
            // Focus toggled again while the island is still showing it: switch over in place
            withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.85)) { shownOn = on }
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
