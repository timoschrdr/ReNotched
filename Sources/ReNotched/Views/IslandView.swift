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
        case .idle, .musicCompact, .volume, .charging: return Self.settle
        default: return Self.bouncy
        }
    }

    var body: some View {
        let mode = model.mode
        let size = model.size(for: mode)
        let expanded = [.copied, .device, .musicExpanded].contains(mode)
        let radius: CGFloat = mode == .musicExpanded ? ExpandedMusicContent.margin : (expanded ? 30 : 15)
        let body = UnevenRoundedRectangle(bottomLeadingRadius: radius, bottomTrailingRadius: radius, style: .continuous)
        // Resting on the physical notch, nothing is drawn beyond it; once active the island gets the notch's top "ears".
        let ear: CGFloat = mode == .idle ? 0 : 6

        ZStack(alignment: .top) {
            content(for: mode)
                .id(mode)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.7, anchor: .top).combined(with: .opacity),
                    removal: .opacity))
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(body)
        .background(alignment: .top) { IslandShape(bottomRadius: radius, ear: ear).fill(.black) }
        .animation(animation(for: mode), value: mode)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(for mode: IslandMode) -> some View {
        switch mode {
        case .idle: Color.clear
        case .volume: VolumeContent(model: model)
        case .charging: ChargingContent(model: model)
        case .copied: CopiedContent(model: model)
        case .device: DeviceContent(model: model)
        case .focus: FocusContent(model: model)
        case .musicCompact: CompactMusicContent(model: model)
        case .musicExpanded: ExpandedMusicContent(model: model, actions: actions)
        }
    }
}
