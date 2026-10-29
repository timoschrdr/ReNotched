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
    var blur: CGFloat, opacity: Double, scale: CGFloat, angle: Double
    func body(content: Content) -> some View {
        content.blur(radius: blur).opacity(opacity).scaleEffect(scale)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
    }
}

extension AnyTransition {
    /// The new cover grows out of nothing while the old one dissolves (like Shazam / Dynamic Island).
    /// `grow` is how much the old cover may swell while it fades; in the compact island there is no room at all,
    /// as the cover sits right against the notch, so it shrinks away instead and nothing reaches into the notch.
    static func cover(grow: CGFloat, turn: Double) -> AnyTransition {
        .asymmetric(
            insertion: .modifier(active: CoverMorph(blur: 10, opacity: 0, scale: 0.3, angle: -turn), identity: CoverMorph(blur: 0, opacity: 1, scale: 1, angle: 0)),
            removal: .modifier(active: CoverMorph(blur: 10, opacity: 0, scale: grow, angle: turn), identity: CoverMorph(blur: 0, opacity: 1, scale: 1, angle: 0)))
    }
}

struct Ripple: View {
    let trigger: Int
    let tint: Color
    let size: CGFloat
    let reach: CGFloat   // final scale of the ring
    @State private var run = false

    var body: some View {
        Circle().strokeBorder(tint, lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(run ? reach : 0.6)
            .opacity(run ? 0 : 0.9)
            .onChange(of: trigger) {
                run = false
                withAnimation(.easeOut(duration: 0.8)) { run = true }
            }
            .allowsHitTesting(false)
    }
}

/// Cover that is replaced with a transition when its `id` changes. Every effect stays inside the island:
/// the compact cover touches the notch, so it only shrinks and fades; the expanded one has its margin to grow into.
struct CoverSlot: View {
    @ObservedObject var model: IslandModel
    let size: CGFloat
    let radius: CGFloat

    private var compact: Bool { size < 30 }

    var body: some View {
        let tint = model.track?.tint ?? .white
        ZStack {
            // Coloured ripple emanating from the cover when a new one appears (like Shazam recognition),
            // reaching no further than the margin (it would otherwise run into the notch)
            if !compact {
                Ripple(trigger: model.track?.artID ?? 0, tint: tint, size: size,
                       reach: 1 + ExpandedMusicContent.margin * 1.5 / size)
            }
            ArtworkView(image: model.track?.artwork, size: size, radius: radius)
                .id(model.track?.artID ?? 0)
                .transition(compact ? .cover(grow: 0.4, turn: 0) : .cover(grow: 1.2, turn: 60))
                .scaleEffect(model.isPlaying ? 1 : 0.78)   // shrinks while paused, like the real Dynamic Island
                .animation(.spring(response: 0.4, dampingFraction: 0.65), value: model.isPlaying)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.6, dampingFraction: 0.58), value: model.track?.artID)
    }
}
