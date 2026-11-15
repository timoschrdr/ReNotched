import SwiftUI

// MARK: - Headphones connected

/// Headphones or a mouse: Apple's picture of the model where the Mac has one, otherwise its symbol; the name below and
/// the battery as a ring.

struct DeviceContent: View {
    @ObservedObject var model: IslandModel
    @State private var appeared = false

    var body: some View {
        let (name, battery, symbol, picture): (String, Int?, String, NSImage?) = {
            if case let .device(n, b, s, i)? = model.transient { return (n, b, s, i.flatMap(DeviceImage.image)) }
            return ("", nil, HeadphoneSymbol.generic, nil)
        }()
        let level = Double(battery ?? 0) / 100

        VStack(spacing: 0) {
            SideLayout(notchWidth: model.notch.width, height: model.notch.height, leftAlignment: .center, rightAlignment: .center) {
                if let picture {
                    Image(nsImage: picture).resizable().interpolation(.high).scaledToFit()
                        .frame(width: 26, height: 26)
                        .scaleEffect(appeared ? 1 : 0.6).opacity(appeared ? 1 : 0)
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, options: .nonRepeating, value: appeared)
                }
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

/// Ring that fills with the charge, with the percentage in the middle. Apple's charging green like its battery widget,
/// red at 20 % or less.
struct BatteryRing: View {
    let percent: Int
    let level: Double   // animated 0…1 fill

    private var color: Color { percent <= 20 ? .red : .charging }

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
        .frame(width: 26, height: 26)
        .animation(.spring(response: 0.9, dampingFraction: 0.85), value: level)
        .animation(.easeInOut(duration: 0.3), value: color)
    }
}
