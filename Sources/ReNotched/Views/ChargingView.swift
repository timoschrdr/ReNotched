import SwiftUI

// MARK: - Charging

struct ChargingContent: View {
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
