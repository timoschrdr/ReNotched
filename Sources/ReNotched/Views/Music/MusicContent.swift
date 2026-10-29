import SwiftUI

struct CompactMusicContent: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
            CoverSlot(model: model, size: 22, radius: 6)
        } right: {
            EqualizerView(active: model.isPlaying, tint: model.track?.tint ?? .white)
        }
    }
}

/// The expanded player, laid out like the Dynamic Island on the MacBook Pro: cover top left beside the camera,
/// title and artist next to it, the equalizer top right, a full-width progress bar and large controls.
/// All content keeps the same inset (`margin`) as the island's bottom corner radius, so it sits concentric
/// with the island's outline, as Apple's guidelines for the Dynamic Island ask.
struct ExpandedMusicContent: View {
    @ObservedObject var model: IslandModel
    let actions: MusicActions

    static let margin: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 17) {
                CoverSlot(model: model, size: 49, radius: 10)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.track?.title ?? "")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    Text(model.track?.artist ?? "")
                        .font(.system(size: 16)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                .padding(.top, 12)                        // the text sits just below the camera
                Spacer(minLength: 8)
                EqualizerView(active: model.isPlaying, tint: model.track?.tint ?? .white, height: 14)
                    .padding(.top, 12)
            }
            .frame(height: 49)

            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                ProgressRow(position: model.livePosition, duration: model.track?.duration ?? 0, seek: actions.seek)
            }
            .padding(.top, 25)

            HStack(spacing: 0) {
                ControlButton(symbol: "backward.fill", size: 25, action: actions.previous)
                Spacer()
                ControlButton(symbol: model.isPlaying ? "pause.fill" : "play.fill", size: 30, action: actions.playPause)
                    .contentTransition(.symbolEffect(.replace))
                Spacer()
                ControlButton(symbol: "forward.fill", size: 25, action: actions.next)
            }
            .padding(.horizontal, 30)
            .padding(.top, 19)
        }
        .padding(.horizontal, Self.margin)
        .padding(.top, 24)
        .padding(.bottom, 30)
    }
}
