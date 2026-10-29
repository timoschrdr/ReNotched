import SwiftUI

// MARK: - Left / right of the notch

/// Places content directly beside the physical notch: the left part ends exactly where the notch begins, the right
/// part starts exactly where it ends. The notch is black like the island, so content touching it makes the island as
/// compact as possible. The island is only as wide as the wider part needs (see `IslandModel.size(for:)`); the
/// narrower part still hugs the notch, unless `leftAlignment` pins it to the outer edge.
struct SideLayout<L: View, R: View>: View {
    /// Space between the notch edge and the content.
    static var gap: CGFloat { 0 }
    /// Space between the content and the island's outer edge: the same as the space above and below a 16 pt symbol
    /// in the compact island, so the content is inset evenly (concentric) and reaches right up to that margin.
    static var outer: CGFloat { 9 }

    let notchWidth: CGFloat
    let height: CGFloat
    var leftAlignment: Alignment = .trailing
    @ViewBuilder var left: L
    @ViewBuilder var right: R

    var body: some View {
        HStack(spacing: 0) {
            left.frame(maxWidth: .infinity, alignment: leftAlignment)
            Color.clear.frame(width: notchWidth + 2 * Self.gap)
            right.frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Self.outer)
        .frame(height: height)
    }
}
