// Generates Resources/AppIcon.icns. Usage: swift scripts/make-icon.swift
import AppKit

func render(size: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // macOS icon grid: 824/1024 content area, ~185/1024 corner radius.
    let s = size / 1024
    let rect = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: rect, xRadius: 185 * s, yRadius: 185 * s)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 20 * s
    shadow.shadowOffset = NSSize(width: 0, height: -8 * s)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(srgbRed: 0.00, green: 0.73, blue: 0.60, alpha: 1),
        NSColor(srgbRed: 0.02, green: 0.45, blue: 0.56, alpha: 1),
    ])!.draw(in: shape, angle: -90)

    // A status dot with two faint pulse rings: the same visual language as the menu bar glyph.
    let center = NSPoint(x: rect.midX, y: rect.midY)
    for (radius, alpha) in [(330.0, 0.18), (250.0, 0.30)] {
        let r = CGFloat(radius) * s
        let ring = NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ring.lineWidth = 14 * s
        NSColor.white.withAlphaComponent(alpha).setStroke()
        ring.stroke()
    }
    let dotRadius = 130.0 * s
    let dot = NSBezierPath(ovalIn: NSRect(x: center.x - dotRadius, y: center.y - dotRadius,
                                          width: dotRadius * 2, height: dotRadius * 2))
    NSColor.white.setFill()
    dot.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(size: CGFloat(base)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(size: CGFloat(base * 2)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try! task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "OK: Resources/AppIcon.icns" : "iconutil failed")
