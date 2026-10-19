// Generates the icon artwork: swift Tools/make-icon.swift
//  - Resources/AppIcon.icon/Assets/island.png: foreground layer of the native macOS 26 icon (background and
//    light/dark variants are defined in Resources/AppIcon.icon/icon.json and compiled by actool in build.sh)
//  - docs/icon-light.png and docs/icon-dark.png for the README
import AppKit

let S: CGFloat = 1024
func render(dark: Bool, foregroundOnly: Bool = false) -> NSImage {
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
if foregroundOnly {   // layer art fills the whole canvas; the system masks and tints it
    let cg = NSGraphicsContext.current!.cgContext
    cg.scaleBy(x: 1024.0 / 824.0, y: 1024.0 / 824.0); cg.translateBy(x: -100, y: -100)
}
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGraphicsContext.current?.saveGraphicsState()
if !foregroundOnly { squircle.addClip() }
let colors = dark
    ? [NSColor(red: 0.13, green: 0.18, blue: 0.40, alpha: 1), NSColor(red: 0.26, green: 0.13, blue: 0.44, alpha: 1)]
    : [NSColor(red: 0.36, green: 0.55, blue: 0.98, alpha: 1), NSColor(red: 0.55, green: 0.32, blue: 0.9, alpha: 1)]
if !foregroundOnly { NSGradient(colors: colors)!.draw(in: body, angle: -60) }
// Menu bar strip
if !foregroundOnly {
    NSColor(white: 1, alpha: dark ? 0.08 : 0.14).setFill()
    NSRect(x: 100, y: 840, width: 824, height: 84).fill()
}
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
return img
}

func png(_ image: NSImage, px: Int) -> Data {
    // Draw into a bitmap of exactly px × px pixels (lockFocus would double it on Retina displays).
    let out = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    out.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return out.representation(using: .png, properties: [:])!
}
let light = render(dark: false), dark = render(dark: true)
try? FileManager.default.createDirectory(atPath: "docs", withIntermediateDirectories: true)
try! png(light, px: 256).write(to: URL(filePath: "docs/icon-light.png"))
try! png(dark, px: 256).write(to: URL(filePath: "docs/icon-dark.png"))
// Layer for the native macOS 26 icon (Icon Composer format): the system adds background and light/dark variants.
try? FileManager.default.createDirectory(atPath: "Resources/AppIcon.icon/Assets", withIntermediateDirectories: true)
try! png(render(dark: false, foregroundOnly: true), px: 1024).write(to: URL(filePath: "Resources/AppIcon.icon/Assets/island.png"))
