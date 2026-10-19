import SwiftUI

struct MusicActions {
    var playPause: () -> Void
    var next: () -> Void
    var previous: () -> Void
    var seek: (Double) -> Void
}

struct IslandView: View {
    @ObservedObject var model: IslandModel
    let actions: MusicActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let bouncy = Animation.spring(response: 0.46, dampingFraction: 0.7)
    /// No overshoot when collapsing, otherwise the island would briefly get smaller than the notch.
    private static let settle = Animation.spring(response: 0.4, dampingFraction: 0.92)

    private func animation(for mode: IslandMode) -> Animation {
        if reduceMotion { return .easeInOut(duration: 0.2) }   // honour System Settings → Accessibility → Reduce Motion
        switch mode {
        case .idle, .musicCompact, .volume: return Self.settle
        default: return Self.bouncy
        }
    }

    var body: some View {
        let mode = model.mode
        let size = model.size(for: mode)
        let expanded = [.copied, .device, .focus, .musicExpanded].contains(mode)
        let shape = UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: expanded ? 30 : 15,
            bottomTrailingRadius: expanded ? 30 : 15,
            topTrailingRadius: 0,
            style: .continuous)

        ZStack(alignment: .top) {
            Color.black
            content(for: mode)
                .id(mode)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.7, anchor: .top).combined(with: .opacity),
                    removal: .opacity))
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .animation(animation(for: mode), value: mode)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(for mode: IslandMode) -> some View {
        switch mode {
        case .idle: Color.clear
        case .volume:
            if case .charging? = model.transient { ChargingContent(model: model) } else { VolumeContent(model: model) }
        case .copied: CopiedContent(model: model)
        case .device: DeviceContent(model: model)
        case .focus: FocusContent(model: model)
        case .musicCompact: CompactMusicContent(model: model)
        case .musicExpanded: ExpandedMusicContent(model: model, actions: actions)
        }
    }
}
