import SwiftUI

/// The island's silhouette: rounded bottom corners and top corners that are either concave "ears" (the compact
/// island flaring into the display edge like the notch) or convex (the expanded player, a rounded rectangle like
/// Apple's on the MacBook Pro).
///
/// `top` is a signed radius: negative values draw concave ears of that size outside `rect`, positive values round
/// the top corners inwards. One value lets the corners morph smoothly from one form into the other. Because the
/// ears extend beyond `rect`, apply this as a background, not as a clip.
struct IslandShape: Shape {
    var bottomRadius: CGFloat
    var top: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomRadius, top) }
        set { bottomRadius = newValue.first; top = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(bottomRadius, rect.height / 2, rect.width / 2)
        let t = min(top, rect.height / 2, rect.width / 2)
        let e = max(-t, 0), c = max(t, 0)   // concave ear / convex radius
        let k: CGFloat = 0.5523             // quarter circle as a cubic Bézier
        var p = Path()
        // top edge
        p.move(to: CGPoint(x: rect.minX - e + c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX + e - c, y: rect.minY))
        // top right: ear bulging towards the island, or a convex corner
        if e > 0 {
            p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + e),
                       control1: CGPoint(x: rect.maxX + e - k * e, y: rect.minY),
                       control2: CGPoint(x: rect.maxX, y: rect.minY + e - k * e))
        } else if c > 0 {
            p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + c),
                       control1: CGPoint(x: rect.maxX - c + k * c, y: rect.minY),
                       control2: CGPoint(x: rect.maxX, y: rect.minY + c - k * c))
        }
        // right side and bottom corners
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.maxY - r + k * r),
                   control2: CGPoint(x: rect.maxX - r + k * r, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                   control1: CGPoint(x: rect.minX + r - k * r, y: rect.maxY),
                   control2: CGPoint(x: rect.minX, y: rect.maxY - r + k * r))
        // left side and top left
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + max(e, c)))
        if e > 0 {
            p.addCurve(to: CGPoint(x: rect.minX - e, y: rect.minY),
                       control1: CGPoint(x: rect.minX, y: rect.minY + e - k * e),
                       control2: CGPoint(x: rect.minX - e + k * e, y: rect.minY))
        } else if c > 0 {
            p.addCurve(to: CGPoint(x: rect.minX + c, y: rect.minY),
                       control1: CGPoint(x: rect.minX, y: rect.minY + c - k * c),
                       control2: CGPoint(x: rect.minX + c - k * c, y: rect.minY))
        }
        p.closeSubpath()
        return p
    }
}
