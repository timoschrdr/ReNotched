// Turns Tools/penguin-source.png (the penguin icon artwork, on a cream rounded-square background) into the
// transparent layer of the native icon: swift Tools/make-penguin-layer.swift
//  - Resources/AppIconPenguin.icon/Assets/penguin.png: the penguin only, filling the 1024 × 1024 canvas
//  - docs/icon-penguin-light.png and docs/icon-penguin-dark.png: previews for the README
// The background is removed with a flood fill from the outside; the cream face and belly stay because they are
// enclosed by the blue body. Edge pixels get a soft alpha, so there is no cream halo.
import AppKit

let sourceURL = URL(filePath: "Tools/penguin-source.png")
let rep = NSBitmapImageRep(data: try! Data(contentsOf: sourceURL))!
let W = rep.pixelsWide, H = rep.pixelsHigh

// RGBA pixels
var px = [UInt8](repeating: 0, count: W * H * 4)
for y in 0..<H { for x in 0..<W {
    let c = rep.colorAt(x: x, y: y)!.usingColorSpace(.sRGB)!
    let i = (y * W + x) * 4
    px[i] = UInt8(c.redComponent * 255); px[i + 1] = UInt8(c.greenComponent * 255); px[i + 2] = UInt8(c.blueComponent * 255); px[i + 3] = 255
} }

let cream = (r: 253.0, g: 247.0, b: 240.0)
func dist(_ i: Int) -> Double {
    let dr = Double(px[i]) - cream.r, dg = Double(px[i + 1]) - cream.g, db = Double(px[i + 2]) - cream.b
    return (dr * dr + dg * dg + db * db).squareRoot()
}

// Rounded-square area of the source (found by probing): x 58…1196, y 52…1202. The belly is cut by its bottom edge,
// so a barrier row seals it before flood filling.
let bottomBarrier = 1199
var ink = [Bool](repeating: false, count: W * H)
for y in 0..<H { for x in 0..<W { ink[y * W + x] = dist((y * W + x) * 4) > 70 || y >= bottomBarrier } }

// flood fill the background from the top-left corner over non-ink pixels
var outside = [Bool](repeating: false, count: W * H)
var stack = [(0, 0)]
outside[0] = true
while let (x, y) = stack.popLast() {
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
        let nx = x + dx, ny = y + dy
        if nx < 0 || ny < 0 || nx >= W || ny >= H { continue }
        let j = ny * W + nx
        if !outside[j] && !ink[j] { outside[j] = true; stack.append((nx, ny)) }
    }
}

// alpha: opaque inside the figure; edge pixels next to the background get a coverage-based alpha with the cream removed
var out = [UInt8](repeating: 0, count: W * H * 4)
let ref = 220.0
for y in 0..<H { for x in 0..<W {
    let j = y * W + x, i = j * 4
    var nearOutside = false
    for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)] {
        let nx = x + dx, ny = y + dy
        if nx >= 0, ny >= 0, nx < W, ny < H, outside[ny * W + nx] { nearOutside = true; break }
    }
    if outside[j] && !nearOutside { continue }                     // background: transparent
    var a = 1.0
    var rgb = (Double(px[i]), Double(px[i + 1]), Double(px[i + 2]))
    if nearOutside {
        a = min(1, dist(i) / ref)
        if a < 0.04 { continue }
        rgb = (min(255, max(0, (rgb.0 - (1 - a) * cream.r) / a)), min(255, max(0, (rgb.1 - (1 - a) * cream.g) / a)),
               min(255, max(0, (rgb.2 - (1 - a) * cream.b) / a)))
    }
    out[i] = UInt8(rgb.0 * a); out[i + 1] = UInt8(rgb.1 * a); out[i + 2] = UInt8(rgb.2 * a); out[i + 3] = UInt8(a * 255)   // premultiplied
} }

// premultiplied RGBA → CGImage
let provider = CGDataProvider(data: Data(out) as CFData)!
let full = CGImage(width: W, height: H, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: W * 4,
                   space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!

// crop and scale to the 1024 canvas: the cut bottom edge lands on the canvas bottom, the outer rim of the source's
// rounded corners is cropped away so the system's own mask never meets it
let crop = CGRect(x: 78, y: 100, width: 1098, height: 1098)
let cropped = full.cropping(to: crop)!

func bitmap(_ size: Int) -> NSBitmapImageRep {
    let r = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                             hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    r.size = NSSize(width: size, height: size)
    return r
}
func draw(_ size: Int, background: NSColor?, rounded: Bool) -> NSBitmapImageRep {
    let r = bitmap(size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: r)
    let ctx = NSGraphicsContext.current!
    ctx.imageInterpolation = .high
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    if rounded { NSBezierPath(roundedRect: rect, xRadius: CGFloat(size) * 0.225, yRadius: CGFloat(size) * 0.225).addClip() }
    if let background { background.setFill(); rect.fill() }
    ctx.cgContext.draw(cropped, in: rect)
    NSGraphicsContext.restoreGraphicsState()
    return r
}
func write(_ r: NSBitmapImageRep, _ path: String) { try! r.representation(using: .png, properties: [:])!.write(to: URL(filePath: path)) }

try? FileManager.default.createDirectory(atPath: "Resources/AppIconPenguin.icon/Assets", withIntermediateDirectories: true)
write(draw(1024, background: nil, rounded: false), "Resources/AppIconPenguin.icon/Assets/penguin.png")
write(draw(256, background: NSColor(srgbRed: 0.992, green: 0.969, blue: 0.941, alpha: 1), rounded: true), "docs/icon-penguin-light.png")
write(draw(256, background: NSColor(srgbRed: 0.090, green: 0.086, blue: 0.110, alpha: 1), rounded: true), "docs/icon-penguin-dark.png")
print("done")
