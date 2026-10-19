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

    private let bouncy = Animation.spring(response: 0.46, dampingFraction: 0.7)
    /// No overshoot when collapsing, otherwise the island would briefly get smaller than the notch.
    private let settle = Animation.spring(response: 0.4, dampingFraction: 0.92)
    private func animation(for mode: IslandMode) -> Animation {
        switch mode {
        case .idle, .musicCompact, .volume: return settle
        default: return bouncy
        }
    }

    var body: some View {
        let mode = model.mode
        let size = model.size(for: mode)
        let expanded = mode == .copied || mode == .device || mode == .musicExpanded
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
        case .musicCompact: CompactMusicContent(model: model)
        case .musicExpanded: ExpandedMusicContent(model: model, actions: actions)
        }
    }
}

// MARK: - Left / right of the notch

private struct SideLayout<L: View, R: View>: View {
    let notchWidth: CGFloat
    let height: CGFloat
    @ViewBuilder var left: L
    @ViewBuilder var right: R

    var body: some View {
        HStack(spacing: 0) {
            left.frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: notchWidth)
            right.frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: height)
    }
}

// MARK: - Volume

private struct VolumeContent: View {
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
                    .frame(width: 42 * CGFloat(shown))
            }
            .frame(width: 42, height: 5)
            .animation(.smooth(duration: 0.18), value: shown)
        }
    }
}

// MARK: - Charging

private struct ChargingContent: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        let (percent, plugged): (Int, Bool) = {
            if case let .charging(p, c)? = model.transient { return (p, c) }
            return (0, false)
        }()
        SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
            Image(systemName: plugged ? "bolt.fill" : "battery.50percent")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(plugged ? .green : .white)
                .symbolEffect(.bounce, options: .nonRepeating, value: plugged)
        } right: {
            Text("\(percent)%").font(.system(size: 13, weight: .semibold).monospacedDigit()).foregroundStyle(.white)
        }
    }
}

// MARK: - Headphones connected

private struct DeviceContent: View {
    @ObservedObject var model: IslandModel
    @State private var appeared = false

    var body: some View {
        let (name, battery): (String, Int?) = {
            if case let .device(n, b)? = model.transient { return (n, b) }
            return ("", nil)
        }()
        let level = Double(battery ?? 0) / 100

        VStack(spacing: 0) {
            SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
                Image(systemName: "headphones")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating, value: appeared)
            } right: {
                if let battery {
                    BatteryRing(percent: battery, level: appeared ? level : 0)
                } else {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundStyle(.green)
                }
            }
            Text(name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white).lineLimit(1)
                .frame(height: 30)
        }
        .onAppear { withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.15)) { appeared = true } }
    }
}

/// Ring that fills with the charge, with the percentage in the middle. Yellow at 20 % or less, red at 10 % or less.
private struct BatteryRing: View {
    let percent: Int
    let level: Double   // animated 0…1 fill

    private var color: Color { percent <= 10 ? .red : percent <= 20 ? .yellow : .white }

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.22), lineWidth: 3)
            Circle().trim(from: 0, to: max(0.001, level))
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(.system(size: 8.5, weight: .semibold).monospacedDigit())
                .minimumScaleFactor(0.7).lineLimit(1)
                .foregroundStyle(.white)
        }
        .frame(width: 28, height: 28)
        .animation(.spring(response: 0.9, dampingFraction: 0.85), value: level)
        .animation(.easeInOut(duration: 0.3), value: color)
    }
}

// MARK: - Copied

private struct CopiedContent: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        let (preview, symbol): (String, String) = {
            if case let .copied(p, s)? = model.transient { return (p, s) }
            return ("", "doc.on.doc")
        }()

        VStack(spacing: 0) {
            SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating, value: preview)
            } right: {
                HStack(spacing: 5) {
                    Text("Copied")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, options: .nonRepeating, value: preview)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                Text(preview)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 30)
        }
    }
}

// MARK: - Music

private struct ArtworkView: View {
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

private struct CoverMorph: ViewModifier {
    var blur: CGFloat, opacity: Double, scale: CGFloat, angle: Double
    func body(content: Content) -> some View {
        content.blur(radius: blur).opacity(opacity).scaleEffect(scale)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
    }
}

private extension AnyTransition {
    /// The new cover grows out of nothing while the old one dissolves (like Shazam / Dynamic Island).
    static var cover: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: CoverMorph(blur: 14, opacity: 0, scale: 0.15, angle: -80), identity: CoverMorph(blur: 0, opacity: 1, scale: 1, angle: 0)),
            removal: .modifier(active: CoverMorph(blur: 14, opacity: 0, scale: 1.6, angle: 80), identity: CoverMorph(blur: 0, opacity: 1, scale: 1, angle: 0)))
    }
}

private struct Ripple: View {
    let trigger: Int
    let tint: Color
    let size: CGFloat
    @State private var run = false

    var body: some View {
        Circle().strokeBorder(tint, lineWidth: 2)
            .frame(width: size, height: size)
            .scaleEffect(run ? 2.6 : 0.6)
            .opacity(run ? 0 : 0.9)
            .onChange(of: trigger) {
                run = false
                withAnimation(.easeOut(duration: 0.8)) { run = true }
            }
            .allowsHitTesting(false)
    }
}

/// Cover that is replaced with a transition when its `id` changes.
private struct CoverSlot: View {
    @ObservedObject var model: IslandModel
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        let tint = model.track?.tint ?? .white
        ZStack {
            // Coloured ripple emanating from the cover when a new one appears (like Shazam recognition)
            Ripple(trigger: model.track?.artID ?? 0, tint: tint, size: size)
            ArtworkView(image: model.track?.artwork, size: size, radius: radius)
                .id(model.track?.artID ?? 0)
                .transition(.cover)
                .scaleEffect(model.isPlaying ? 1 : 0.78)   // shrinks while paused, like the real Dynamic Island
                .animation(.spring(response: 0.4, dampingFraction: 0.65), value: model.isPlaying)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.6, dampingFraction: 0.58), value: model.track?.artID)
    }
}

/// Smoothing state for the equalizer: bars rise and fall gradually instead of jumping.
private final class EqualizerState {
    var amplitude = 0.0
    var last = Date()

    func step(to target: Double, at now: Date) -> Double {
        let dt = min(now.timeIntervalSince(last), 0.1)
        last = now
        amplitude += (target - amplitude) * (1 - exp(-dt / (target > amplitude ? 0.12 : 0.28)))
        return amplitude
    }
}

private struct EqualizerView: View {
    let active: Bool
    var tint: Color = .white
    var height: CGFloat = 16
    @State private var state = EqualizerState()
    @State private var running = false
    @State private var generation = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !running)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let amp = state.step(to: active ? 1 : 0, at: ctx.date)
            HStack(spacing: 2.5) {
                ForEach(0..<4, id: \.self) { i in
                    let phase = Double(i)
                    let wave = 0.3 + 0.7 * abs(sin(t * (2.4 + phase * 0.8) + phase * 1.3))
                    let h = 0.18 + (wave - 0.18) * amp
                    Capsule().fill(tint).frame(width: 3, height: height * h)
                }
            }
            .frame(height: height)
        }
        .animation(.easeInOut(duration: 0.6), value: tint)
        .onAppear { running = active }
        .onChange(of: active) {
            generation += 1
            if active { running = true } else {
                // keep the timeline alive until the bars have settled
                let mine = generation
                Task { try? await Task.sleep(for: .seconds(1.6)); if generation == mine { running = false } }
            }
        }
    }
}

private struct CompactMusicContent: View {
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

private struct ExpandedMusicContent: View {
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
        .padding(.top, model.notch.height + 2)
        .padding(.bottom, 14)
    }
}

private struct ProgressRow: View {
    let position: Double
    let duration: Double
    let tint: Color
    let seek: (Double) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(format(position)).frame(width: 36, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.25))
                    Capsule().fill(tint)
                        .frame(width: geo.size.width * (duration > 0 ? CGFloat(min(position / duration, 1)) : 0))
                }
                .frame(height: 4).frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { g in
                    guard duration > 0, geo.size.width > 0 else { return }
                    seek(duration * Double(min(max(g.location.x / geo.size.width, 0), 1)))
                })
            }
            .frame(height: 14)
            Text(duration > 0 ? "-" + format(max(duration - position, 0)) : "--:--")
                .frame(width: 40, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .medium).monospacedDigit())
        .foregroundStyle(.white.opacity(0.55))
    }

    private func format(_ s: Double) -> String {
        let t = Int(s.rounded(.down))
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}

private struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressStyle())
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.82 : 1)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
