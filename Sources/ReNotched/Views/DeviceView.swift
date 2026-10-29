import SwiftUI

// MARK: - Headphones connected

/// The headphones' symbol (the AirPods model, if known), the name below and the battery as a ring.

struct DeviceContent: View {
    @ObservedObject var model: IslandModel
    @State private var appeared = false

    var body: some View {
        let (name, battery, symbol): (String, Int?, String) = {
            if case let .device(n, b, s)? = model.transient { return (n, b, s) }
            return ("", nil, HeadphoneSymbol.generic)
        }()
        let level = Double(battery ?? 0) / 100

        VStack(spacing: 0) {
            SideLayout(notchWidth: model.notch.width, height: model.notch.height) {
                Image(systemName: symbol)
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
struct BatteryRing: View {
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
