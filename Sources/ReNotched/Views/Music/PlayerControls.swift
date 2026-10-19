import SwiftUI

struct ProgressRow: View {
    let position: Double
    let duration: Double
    let tint: Color
    let seek: (Double) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(format(position)).frame(width: 36, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * (duration > 0 ? CGFloat(min(position / duration, 1)) : 0))
                }
                .frame(height: 4).frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { g in
                    guard duration > 0, geo.size.width > 0 else { return }
                    seek(duration * Double(min(max(g.location.x / geo.size.width, 0), 1)))
                })
            }
            .frame(height: 14)
            Text(duration > 0 ? "-" + format(max(duration - position, 0)) : "--:--")
                .frame(width: 40, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(.white.opacity(0.55))
    }

    private func format(_ s: Double) -> String {
        let t = Int(s.rounded(.down))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
