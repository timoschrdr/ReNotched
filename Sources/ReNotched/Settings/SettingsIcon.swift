import SwiftUI

/// A small app-style icon tile like the ones in macOS 26: in dark mode a black tile with a soft dark gradient,
/// a glyph shaded in its colour, and a thin rim that catches the light at the top; in light mode a coloured tile
/// with a white glyph and the same rim.
struct SettingsIcon: View {
    let symbol: String
    let color: Color
    var size: CGFloat = 30
    @Environment(\.colorScheme) private var scheme

    private var radius: CGFloat { size * 0.3 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let dark = scheme == .dark
        Image(systemName: symbol)
            .font(.system(size: size * 0.47, weight: .semibold))
            .foregroundStyle(dark
                ? AnyShapeStyle(LinearGradient(colors: [color.mix(with: .white, by: 0.35), color], startPoint: .top, endPoint: .bottom))
                : AnyShapeStyle(Color.white))
            .shadow(color: dark ? color.opacity(0.35) : .black.opacity(0.15), radius: size * 0.06, y: size * 0.02)
            .frame(width: size, height: size)
            .background {
                if dark {
                    shape.fill(LinearGradient(colors: [Color(white: 0.17), Color(white: 0.04)], startPoint: .top, endPoint: .bottom))
                } else {
                    shape.fill(LinearGradient(colors: [color.mix(with: .white, by: 0.18), color.mix(with: .black, by: 0.08)],
                                              startPoint: .top, endPoint: .bottom))
                }
            }
            .overlay {
                // the shimmering rim: bright at the top edge, fading towards the bottom
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(dark ? 0.24 : 0.32), .white.opacity(dark ? 0.03 : 0.06),
                                                           .white.opacity(dark ? 0.07 : 0.1)],
                                                  startPoint: .top, endPoint: .bottom),
                                   lineWidth: max(0.5, size * 0.02))
            }
            .shadow(color: .black.opacity(dark ? 0.35 : 0.12), radius: size * 0.05, y: size * 0.03)
    }
}
