import AppKit
import SwiftUI

/// Four bars that dance while music plays and settle smoothly when it stops.
///
/// Drawn with Core Animation: the bars are animated by the system's render server, so the app itself does no
/// work per frame (a SwiftUI timeline redrawing 30 times a second used about 7 % CPU).
struct EqualizerView: NSViewRepresentable {
    let active: Bool
    var tint: Color = .white
    var height: CGFloat = 16

    func makeNSView(context: Context) -> EqualizerLayerView { EqualizerLayerView(height: height) }

    func updateNSView(_ view: EqualizerLayerView, context: Context) {
        view.update(active: active, color: NSColor(tint))
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: EqualizerLayerView, context: Context) -> CGSize? {
        CGSize(width: EqualizerLayerView.width, height: height)
    }
}

final class EqualizerLayerView: NSView {
    static let barWidth: CGFloat = 3, spacing: CGFloat = 2.5, restScale: CGFloat = 0.18
    static let width = 4 * barWidth + 3 * spacing

    /// Heights (as a fraction of the full height) each bar passes through, and how long one round takes.
    private static let patterns: [(values: [CGFloat], duration: CFTimeInterval)] = [
        ([0.35, 0.85, 0.5, 1.0, 0.4, 0.35], 1.10),
        ([0.9, 0.4, 1.0, 0.55, 0.9], 0.95),
        ([0.5, 1.0, 0.35, 0.8, 0.5], 1.25),
        ([0.8, 0.45, 0.9, 0.4, 0.8], 1.05),
    ]

    private let barHeight: CGFloat
    private var bars: [CALayer] = []
    private var isActive: Bool?

    init(height: CGFloat) {
        barHeight = height
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: height))
        wantsLayer = true
        for i in 0..<4 {
            let bar = CALayer()
            bar.bounds = CGRect(x: 0, y: 0, width: Self.barWidth, height: height)
            bar.position = CGPoint(x: CGFloat(i) * (Self.barWidth + Self.spacing) + Self.barWidth / 2, y: height / 2)
            bar.cornerRadius = Self.barWidth / 2
            bar.setValue(Self.restScale, forKeyPath: "transform.scale.y")
            layer?.addSublayer(bar)
            bars.append(bar)
        }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func update(active: Bool, color: NSColor) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.6)
        bars.forEach { $0.backgroundColor = color.cgColor }
        CATransaction.commit()
        guard active != isActive else { return }
        isActive = active
        active ? start() : settle()
    }

    private func start() {
        for (i, bar) in bars.enumerated() {
            let pattern = Self.patterns[i]
            let wave = CAKeyframeAnimation(keyPath: "transform.scale.y")
            wave.values = pattern.values
            wave.calculationMode = .cubic
            wave.duration = pattern.duration
            wave.repeatCount = .infinity
            wave.beginTime = CACurrentMediaTime() + Double(i) * 0.12
            wave.fillMode = .backwards
            bar.removeAnimation(forKey: "sink")
            bar.add(wave, forKey: "wave")
        }
    }

    /// Lets each bar sink from wherever it currently is down to the resting height.
    private func settle() {
        for bar in bars {
            let current = (bar.presentation()?.value(forKeyPath: "transform.scale.y") as? CGFloat) ?? Self.restScale
            bar.removeAnimation(forKey: "wave")
            bar.setValue(Self.restScale, forKeyPath: "transform.scale.y")
            let sink = CABasicAnimation(keyPath: "transform.scale.y")
            sink.fromValue = current
            sink.toValue = Self.restScale
            sink.duration = 0.55
            sink.timingFunction = CAMediaTimingFunction(name: .easeOut)
            bar.add(sink, forKey: "sink")
        }
    }
}
