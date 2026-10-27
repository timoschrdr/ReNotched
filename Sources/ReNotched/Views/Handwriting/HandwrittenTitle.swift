import SwiftUI

/// The app's name written by an invisible pen, like the "hello" on a new Mac: the strokes are drawn one after
/// the other at a constant speed. Closing and reopening the window, or a click on the title, writes it again.
struct HandwrittenTitle: View {
    var height: CGFloat = 46
    @State private var progress = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PenShape(progress: progress)
            .stroke(.primary, style: StrokeStyle(lineWidth: Handwriting.penWidth * height / Handwriting.bounds.height,
                                                 lineCap: .round, lineJoin: .round))
            .aspectRatio(Handwriting.bounds.width / Handwriting.bounds.height, contentMode: .fit)
            .frame(height: height)
            .contentShape(Rectangle())
            .onTapGesture { write() }
            .onAppear { write() }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in progress = 0 }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                if progress == 0 { write() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("ReNotched.")
    }

    private func write() {
        progress = 0
        if reduceMotion { progress = 1; return }
        // After a beat, so the window is on screen when the pen starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.linear(duration: 3.2)) { progress = 1 }
        }
    }
}

/// The part of the handwriting the pen has reached, from 0 (nothing) to 1 (everything).
private struct PenShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let box = Handwriting.bounds
        let scale = min(rect.width / box.width, rect.height / box.height)
        func point(_ p: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + (p.x - box.minX) * scale, y: rect.maxY - (p.y - box.minY) * scale)   // y up → down
        }

        var remaining = CGFloat(progress) * Handwriting.totalDistance
        var path = Path()
        for (index, stroke) in Handwriting.strokes.enumerated() {
            guard remaining > 0 else { break }
            let length = Handwriting.strokeLengths[index]
            var full = Path()
            full.move(to: point(stroke[0].start))
            for s in stroke { full.addCurve(to: point(s.end), control1: point(s.control1), control2: point(s.control2)) }
            path.addPath(remaining >= length ? full : full.trimmedPath(from: 0, to: remaining / length))
            remaining -= length + Handwriting.liftDistance
        }
        return path
    }
}
