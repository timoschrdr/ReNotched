import SwiftUI

// MARK: - Left / right of the notch

/// Places content directly beside the physical notch: the left part ends `gap` points before the notch, the right
/// part starts `gap` points after it. The island is only as wide as these parts need (see `IslandModel.size(for:)`).
struct SideLayout<L: View, R: View>: View {
    /// Space between the notch edge and the content.
    static var gap: CGFloat { 6 }
    /// Space between the content and the island's outer edge: the same as the space above and below a 16 pt symbol
    /// in the compact island, so the content is inset evenly (concentric) and reaches right up to that margin.
    static var outer: CGFloat { 9 }

    let notchWidth: CGFloat
    let height: CGFloat
    @ViewBuilder var left: L
    @ViewBuilder var right: R

    var body: some View {
        HStack(spacing: 0) {
            left.frame(maxWidth: .infinity, alignment: .trailing)
            Color.clear.frame(width: notchWidth + 2 * Self.gap)
            right.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Self.outer)
        .frame(height: height)
    }
}
