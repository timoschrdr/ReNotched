import SwiftUI

// MARK: - Volume

struct VolumeContent: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        let (level, muted, headphones): (Float, Bool, String?) = {
            if case let .volume(l, m, h)? = model.transient { return (l, m, h) }
            return (0, false, nil)
        }()
        let shown = muted ? 0 : level

        SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
            // With headphones connected their symbol replaces the speaker (the exact AirPods model, if known)
            Image(systemName: headphones ?? (muted ? "speaker.slash.fill" : "speaker.wave.3.fill"),
                  variableValue: headphones == nil ? Double(shown) : nil)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(muted ? Color.red : .white)   // muted: red, like on the iPhone
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: muted)
        } right: {
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule().fill(.white)
                    .frame(width: 34 * CGFloat(shown))
            }
            .frame(width: 34, height: 5)
            .animation(.smooth(duration: 0.18), value: shown)
        }
    }
}
