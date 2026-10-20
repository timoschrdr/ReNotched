import SwiftUI

/// The island's silhouette: a rectangle with rounded bottom corners and small concave "ears" at the top corners.
/// The ears flare out above the island like the notch merging into the display's rounded top corners.
/// They are drawn outside `rect` (by `ear` points on each side), so apply this as a background, not as a clip.
struct IslandShape: Shape {
    var bottomRadius: CGFloat
    var ear: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomRadius, ear) }
        set { bottomRadius = newValue.first; ear = max(newValue.second, 0) }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(bottomRadius, rect.height / 2, rect.width / 2)
        let e = max(ear, 0)
        let k: CGFloat = 0.5523   // quarter circle as a cubic Bézier
        var p = Path()
        p.move(to: CGPoint(x: rect.minX - e, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX + e, y: rect.minY))
        // right ear: quarter circle around (maxX + e, minY + e), bulging towards the island
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + e),
                   control1: CGPoint(x: rect.maxX + e - k * e, y: rect.minY),
                   control2: CGPoint(x: rect.maxX, y: rect.minY + e - k * e))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY),
                   control1: CGPoint(x: rect.maxX, y: rect.maxY - r + k * r),
                   control2: CGPoint(x: rect.maxX - r + k * r, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r),
                   control1: CGPoint(x: rect.minX + r - k * r, y: rect.maxY),
                   control2: CGPoint(x: rect.minX, y: rect.maxY - r + k * r))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + e))
        p.addCurve(to: CGPoint(x: rect.minX - e, y: rect.minY),
                   control1: CGPoint(x: rect.minX, y: rect.minY + e - k * e),
                   control2: CGPoint(x: rect.minX - e + k * e, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
