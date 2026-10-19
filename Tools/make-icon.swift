// Generates Resources/AppIcon.icns: swift Tools/make-icon.swift
import AppKit

let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGraphicsContext.current?.saveGraphicsState()
squircle.addClip()
NSGradient(colors: [NSColor(red: 0.36, green: 0.55, blue: 0.98, alpha: 1), NSColor(red: 0.55, green: 0.32, blue: 0.9, alpha: 1)])!
    .draw(in: body, angle: -60)
// Menu bar strip
NSColor(white: 1, alpha: 0.14).setFill()
NSRect(x: 100, y: 840, width: 824, height: 84).fill()
// Island: grows out of the notch, flush with the top edge
let island = NSBezierPath()
let (x0, x1, top, bottom, r): (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) = (252, 772, 924, 600, 110)
island.move(to: NSPoint(x: x0, y: top))
island.line(to: NSPoint(x: x1, y: top))
island.line(to: NSPoint(x: x1, y: bottom + r))
island.curve(to: NSPoint(x: x1 - r, y: bottom), controlPoint1: NSPoint(x: x1, y: bottom + r * 0.45), controlPoint2: NSPoint(x: x1 - r * 0.45, y: bottom))
island.line(to: NSPoint(x: x0 + r, y: bottom))
island.curve(to: NSPoint(x: x0, y: bottom + r), controlPoint1: NSPoint(x: x0 + r * 0.45, y: bottom), controlPoint2: NSPoint(x: x0, y: bottom + r * 0.45))
island.close()
NSColor.black.setFill(); island.fill()
// Cover on the left, equalizer on the right
NSGradient(colors: [NSColor.systemPink, NSColor.systemOrange])!
    .draw(in: NSBezierPath(roundedRect: NSRect(x: 305, y: 650, width: 120, height: 120), xRadius: 30, yRadius: 30), angle: -45)
NSColor.systemPink.setFill()
for (i, h) in [50.0, 100, 70, 90].enumerated() {
    NSBezierPath(roundedRect: NSRect(x: 560 + CGFloat(i) * 42, y: 710 - CGFloat(h) / 2, width: 24, height: CGFloat(h)), xRadius: 12, yRadius: 12).fill()
}
NSGraphicsContext.current?.restoreGraphicsState()
img.unlockFocus()

let dir = "Resources/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
for (name, px) in [("16", 16), ("16@2x", 32), ("32", 32), ("32@2x", 64), ("128", 128), ("128@2x", 256),
                   ("256", 256), ("256@2x", 512), ("512", 512), ("512@2x", 1024)] {
    let out = NSImage(size: NSSize(width: px, height: px))
    out.lockFocus(); NSGraphicsContext.current?.imageInterpolation = .high
    rep.draw(in: NSRect(x: 0, y: 0, width: px, height: px)); out.unlockFocus()
    let png = NSBitmapImageRep(data: out.tiffRepresentation!)!.representation(using: .png, properties: [:])!
    try! png.write(to: URL(filePath: "\(dir)/icon_\(name).png"))
}
