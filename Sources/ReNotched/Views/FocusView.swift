import SwiftUI

/// Focus turned on or off: mode icon and state on top, the mode's name below.
struct FocusContent: View {
    @ObservedObject var model: IslandModel
    @State private var appeared = false

    var body: some View {
        let (name, symbol, on): (String, String, Bool) = {
            if case let .focus(n, s, o)? = model.transient { return (n, s, o) }
            return ("", "moon.fill", false)
        }()

        VStack(spacing: 0) {
            SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
                Image(systemName: on ? symbol : "moon.zzz.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(on ? Color.indigo : .white.opacity(0.6))
                    .symbolEffect(.bounce, options: .nonRepeating, value: appeared)
                    .scaleEffect(appeared ? 1 : 0.4)
            } right: {
                Text(on ? "On" : "Off")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(on ? Color.indigo : .white.opacity(0.18), in: Capsule())
                    .foregroundStyle(.white)
            }
            Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                .frame(height: 30)
        }
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.6).delay(0.1)) { appeared = true } }
    }
}
