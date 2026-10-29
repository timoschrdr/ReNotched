import SwiftUI

// MARK: - Volume

struct VolumeContent: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        let (level, muted): (Float, Bool) = {
            if case let .volume(l, m)? = model.transient { return (l, m) }
            return (0, false)
        }()
        let shown = muted ? 0 : level

        SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
            Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.3.fill",
                  variableValue: Double(shown))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(muted ? Color.red : .white)   // muted: red slashed speaker, like on the iPhone
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
