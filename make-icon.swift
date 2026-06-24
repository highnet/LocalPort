#!/usr/bin/env swift
// Generates AppIcon.icns: a signal-beacon glyph on a deep blue gradient.
import AppKit

func drawIcon(px: Int) -> Data {
    let size = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Rounded background with diagonal gradient.
    let radius = size * 0.2237
    cg.saveGState()
    cg.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    cg.clip()
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [CGColor(red: 0.10, green: 0.16, blue: 0.34, alpha: 1),
                 CGColor(red: 0.04, green: 0.06, blue: 0.13, alpha: 1)] as CFArray,
        locations: [0, 1])!
    cg.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    // Beacon: a bright dot with three expanding signal arcs.
    let center = CGPoint(x: size * 0.5, y: size * 0.42)
    let accent = CGColor(red: 0.20, green: 0.90, blue: 0.62, alpha: 1)

    for (i, r) in [0.18, 0.28, 0.38].enumerated() {
        cg.setStrokeColor(CGColor(red: 0.20, green: 0.90, blue: 0.62,
                                  alpha: 0.55 - Double(i) * 0.15))
        cg.setLineWidth(size * 0.032)
        cg.setLineCap(.round)
        // Upper arc, opening downward (a broadcast fan).
        cg.addArc(center: center, radius: size * CGFloat(r),
                  startAngle: .pi * 0.18, endAngle: .pi * 0.82, clockwise: false)
        cg.strokePath()
    }

    // Glowing core dot.
    cg.setShadow(offset: .zero, blur: size * 0.06, color: accent.copy(alpha: 0.9))
    cg.setFillColor(accent)
    let dot = size * 0.075
    cg.fillEllipse(in: CGRect(x: center.x - dot, y: center.y - dot, width: dot * 2, height: dot * 2))

    cg.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
let iconset = "LocalPort.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in specs {
    let data = drawIcon(px: px)
    try! data.write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
print("Wrote \(iconset). Run: iconutil -c icns \(iconset) -o AppIcon.icns")
