import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.iconset"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                     samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let bg = NSBezierPath(roundedRect: NSRect(x: s * 0.06, y: s * 0.06, width: s * 0.88, height: s * 0.88), xRadius: s * 0.2, yRadius: s * 0.2)
    NSGradient(starting: NSColor(red: 0.16, green: 0.58, blue: 0.38, alpha: 1), ending: NSColor(red: 0.06, green: 0.36, blue: 0.26, alpha: 1))?.draw(in: bg, angle: -90)

    let grid = NSRect(x: s * 0.22, y: s * 0.27, width: s * 0.56, height: s * 0.46)
    NSColor.white.withAlphaComponent(0.95).setFill()
    NSBezierPath(roundedRect: grid, xRadius: s * 0.03, yRadius: s * 0.03).fill()
    NSColor(red: 0.16, green: 0.58, blue: 0.38, alpha: 0.35).setFill()
    NSBezierPath(rect: NSRect(x: grid.minX, y: grid.maxY - grid.height / 3, width: grid.width, height: grid.height / 3)).fill()
    NSColor(red: 0.06, green: 0.36, blue: 0.26, alpha: 0.6).setStroke()
    let lines = NSBezierPath()
    lines.lineWidth = max(1, s * 0.012)
    for i in 1..<3 {
        let y = grid.minY + grid.height * CGFloat(i) / 3
        lines.move(to: NSPoint(x: grid.minX, y: y)); lines.line(to: NSPoint(x: grid.maxX, y: y))
        let x = grid.minX + grid.width * CGFloat(i) / 3
        lines.move(to: NSPoint(x: x, y: grid.minY)); lines.line(to: NSPoint(x: x, y: grid.maxY))
    }
    lines.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let sizes: [(String, Int)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                              ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024)]
for (name, px) in sizes {
    if let data = render(px) { try? data.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png")) }
}
