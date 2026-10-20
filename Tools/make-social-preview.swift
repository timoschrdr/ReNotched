// Creates docs/social-preview.png (1280 × 640, the image GitHub shows when the repository is shared):
//   swift Tools/make-social-preview.swift        (needs docs/icon-light.png from Tools/make-icon-previews.sh)
import AppKit
import CoreText

let W = 1280, H = 640
func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let titleColor = color(0x38333E), accent = color(0x3F4FC8), taglineColor = color(0x756E78)

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W, pixelsHigh: H, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
rep.size = NSSize(width: W, height: H)
NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = ctx
ctx.imageInterpolation = .high
let cg = ctx.cgContext

// warm cream background: bilinear blend of the four corner colours
let cornerTL: [Double] = [0xFD, 0xF7, 0xF2], cornerTR: [Double] = [0xF8, 0xEE, 0xE6]
let cornerBL: [Double] = [0xFB, 0xF5, 0xEE], cornerBR: [Double] = [0xF5, 0xEB, 0xE3]
for y in 0..<H {
    let v = Double(y) / Double(H - 1)   // y from the top
    for x in 0..<W {
        let u = Double(x) / Double(W - 1)
        var rgb: [CGFloat] = []
        for k in 0..<3 {
            let top: Double = cornerTL[k] * (1 - u) + cornerTR[k] * u
            let bottom: Double = cornerBL[k] * (1 - u) + cornerBR[k] * u
            rgb.append(CGFloat((top * (1 - v) + bottom * v) / 255))
        }
        NSColor(srgbRed: rgb[0], green: rgb[1], blue: rgb[2], alpha: 1).setFill()
        NSRect(x: x, y: H - 1 - y, width: 1, height: 1).fill()
    }
}

// layout: icon, gap, text block – centred horizontally as one group
let iconSize: CGFloat = 344, gap: CGFloat = 86, maxTextWidth: CGFloat = 560

// text
func font(_ size: CGFloat, _ weight: NSFont.Weight, rounded: Bool) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    guard rounded, let d = base.fontDescriptor.withDesign(.rounded) else { return base }
    return NSFont(descriptor: d, size: size) ?? base
}
func line(_ text: String, _ font: NSFont, _ color: NSColor, kern: CGFloat = 0) -> CTLine {
    CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .kern: kern]))
}
func draw(_ ctLine: CTLine, x: CGFloat, baseline: CGFloat) {
    cg.textPosition = CGPoint(x: x, y: CGFloat(H) - baseline)
    CTLineDraw(ctLine, cg)
}
var size: CGFloat = 134                                     // the title shrinks until "ReNotched." fits
var name = line("ReNotched", font(size, .heavy, rounded: true), titleColor, kern: -2)
var dot = line(".", font(size, .heavy, rounded: true), accent, kern: -2)
while CTLineGetTypographicBounds(name, nil, nil, nil) + CTLineGetTypographicBounds(dot, nil, nil, nil) > maxTextWidth && size > 60 {
    size -= 2
    name = line("ReNotched", font(size, .heavy, rounded: true), titleColor, kern: -2)
    dot = line(".", font(size, .heavy, rounded: true), accent, kern: -2)
}
let titleWidth = CGFloat(CTLineGetTypographicBounds(name, nil, nil, nil) + CTLineGetTypographicBounds(dot, nil, nil, nil))
let blockWidth = iconSize + gap + titleWidth
let iconX = (CGFloat(W) - blockWidth) / 2
let textX = iconX + iconSize + gap

// icon with a soft shadow
let icon = NSImage(contentsOf: URL(filePath: "docs/icon-light.png"))!
ctx.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.18); shadow.shadowOffset = NSSize(width: 0, height: -12); shadow.shadowBlurRadius = 30
shadow.set()
icon.draw(in: NSRect(x: iconX, y: CGFloat(H) - 154 - iconSize, width: iconSize, height: iconSize))
ctx.restoreGraphicsState()

let titleBaseline: CGFloat = 322
draw(name, x: textX, baseline: titleBaseline)
draw(dot, x: textX + CGFloat(CTLineGetTypographicBounds(name, nil, nil, nil)), baseline: titleBaseline)

let tagFont = font(35, .medium, rounded: false)
draw(line("Turn your MacBook notch", tagFont, taglineColor), x: textX - 2, baseline: 394)
draw(line("into a Dynamic Island.", tagFont, taglineColor), x: textX - 2, baseline: 446)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(filePath: "docs/social-preview.png"))
print("title size", size)
