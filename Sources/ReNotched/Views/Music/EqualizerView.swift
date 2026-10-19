import SwiftUI

/// Smoothing state for the equalizer: bars rise and fall gradually instead of jumping.
final class EqualizerState {
    var amplitude = 0.0
    var last = Date()

    func step(to target: Double, at now: Date) -> Double {
        let dt = min(now.timeIntervalSince(last), 0.1)
        last = now
        amplitude += (target - amplitude) * (1 - exp(-dt / (target > amplitude ? 0.12 : 0.28)))
        return amplitude
    }
}

struct EqualizerView: View {
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
