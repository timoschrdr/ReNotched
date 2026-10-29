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

/// The expanded player, laid out like the Dynamic Island on the MacBook Pro: cover top left, title and artist
/// beside it below the camera, the equalizer top right, a progress bar and the controls.
/// Following Apple's guidelines for the Dynamic Island, all content uses the same inset (`margin`) to the edge,
/// reaches right up to it, and the island's corners are concentric with the cover:
/// corner radius = margin + cover radius.
struct ExpandedMusicContent: View {
    @ObservedObject var model: IslandModel
    let actions: MusicActions

    static let margin: CGFloat = 16
    static let coverSize: CGFloat = 46
    static let coverRadius: CGFloat = 10
    static var cornerRadius: CGFloat { margin + coverRadius }

    /// Offset of the text from the top margin so it clears the notch.
    private var belowCamera: CGFloat { max(0, model.notch.height + model.notchExtra + 3 - Self.margin) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                CoverSlot(model: model, size: Self.coverSize, radius: Self.coverRadius)
                // the text starts just below the camera
                VStack(alignment: .leading, spacing: 0) {
                    Text(model.track?.title ?? "")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(.white).lineLimit(1)
                    Text(model.track?.artist ?? "")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                }
                .padding(.top, belowCamera)
                Spacer(minLength: 8)
                EqualizerView(active: model.isPlaying, tint: model.track?.tint ?? .white, height: 14)
                    .padding(.top, belowCamera + 3)
            }

            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                ProgressRow(position: model.livePosition, duration: model.track?.duration ?? 0, seek: actions.seek)
            }
            .padding(.top, 14)

            HStack(spacing: 0) {
                ControlButton(symbol: "backward.fill", size: 22, action: actions.previous)
                Spacer()
                ControlButton(symbol: model.isPlaying ? "pause.fill" : "play.fill", size: 26, action: actions.playPause)
                    .contentTransition(.symbolEffect(.replace))
                Spacer()
                ControlButton(symbol: "forward.fill", size: 22, action: actions.next)
            }
            .padding(.horizontal, 36)
            .padding(.top, 6)
        }
        .padding([.horizontal, .top, .bottom], Self.margin)
    }
}
