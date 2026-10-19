import SwiftUI

// MARK: - Left / right of the notch

struct SideLayout<L: View, R: View>: View {
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
