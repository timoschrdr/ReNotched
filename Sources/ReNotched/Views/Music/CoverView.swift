import SwiftUI

struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note").font(.system(size: size * 0.45, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct CoverMorph: ViewModifier {
    var blur: CGFloat, opacity: Double, scale: CGFloat
    func body(content: Content) -> some View {
        content.blur(radius: blur).opacity(opacity).scaleEffect(scale)
    }
}

extension AnyTransition {
    /// A soft crossfade like Apple's player: the new cover fades in from slightly smaller while the old one fades
    /// out in place. Nothing grows, so the cover never reaches into the notch.
    static var cover: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: CoverMorph(blur: 6, opacity: 0, scale: 0.88), identity: CoverMorph(blur: 0, opacity: 1, scale: 1)),
            removal: .modifier(active: CoverMorph(blur: 6, opacity: 0, scale: 1), identity: CoverMorph(blur: 0, opacity: 1, scale: 1)))
    }
}

/// Cover that crossfades to the new one when its `id` changes.
struct CoverSlot: View {
    @ObservedObject var model: IslandModel
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        ZStack {
            ArtworkView(image: model.track?.artwork, size: size, radius: radius)
                .id(model.track?.artID ?? 0)
                .transition(.cover)
                .scaleEffect(model.isPlaying ? 1 : 0.78)   // shrinks while paused, like the real Dynamic Island
                .animation(.spring(response: 0.4, dampingFraction: 0.65), value: model.isPlaying)
        }
        .frame(width: size, height: size)
        .animation(.easeInOut(duration: 0.45), value: model.track?.artID)
    }
}
