import SwiftUI

struct CompactMusicContent: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
            CoverSlot(model: model, size: 22, radius: 6)
        } right: {
            EqualizerView(active: model.isPlaying, tint: model.track?.tint ?? .white)
        }
        .padding(.horizontal, -4)
    }
}

struct ExpandedMusicContent: View {
    @ObservedObject var model: IslandModel
    let actions: MusicActions

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                CoverSlot(model: model, size: 52, radius: 11)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.track?.title ?? "")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                    Text(model.track?.artist ?? "")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
                Spacer(minLength: 0)
                EqualizerView(active: model.isPlaying, tint: model.track?.tint ?? .white, height: 20)
            }

            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                ProgressRow(position: model.livePosition, duration: model.track?.duration ?? 0,
                            tint: model.track?.tint ?? .white, seek: actions.seek)
            }

            HStack(spacing: 34) {
                ControlButton(symbol: "backward.fill", size: 18, action: actions.previous)
                ControlButton(symbol: model.isPlaying ? "pause.fill" : "play.fill", size: 24, action: actions.playPause)
                    .contentTransition(.symbolEffect(.replace))
                ControlButton(symbol: "forward.fill", size: 18, action: actions.next)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, model.notch.height + model.notchExtra + 1)
        .padding(.bottom, 14)
    }
}
