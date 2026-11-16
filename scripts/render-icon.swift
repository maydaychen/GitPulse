import AppKit

func renderIcon(pixelSize: Int, to destination: URL) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Cannot allocate bitmap")
    }
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Cannot create graphics context")
    }
    NSGraphicsContext.current = ctx

    let s = CGFloat(pixelSize) / 1024.0
    NSColor(red: 11.0 / 255.0, green: 13.0 / 255.0, blue: 19.0 / 255.0, alpha: 1.0).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024 * s, height: 1024 * s)).fill()

    let bezel = NSBezierPath(
        roundedRect: NSRect(x: 84 * s, y: 84 * s, width: 856 * s, height: 856 * s),
        xRadius: 180 * s,
        yRadius: 180 * s
    )
    NSColor(red: 18.0 / 255.0, green: 21.0 / 255.0, blue: 30.0 / 255.0, alpha: 1.0).setFill()
    bezel.fill()
    NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.08).setStroke()
    bezel.lineWidth = 4 * s
    bezel.stroke()

    let emerald = NSColor(red: 16.0 / 255.0, green: 185.0 / 255.0, blue: 129.0 / 255.0, alpha: 1.0)
    let brightEmerald = NSColor(red: 52.0 / 255.0, green: 211.0 / 255.0, blue: 153.0 / 255.0, alpha: 1.0)

    let trace = NSBezierPath()
    trace.lineWidth = 44 * s
    trace.lineCapStyle = .round
    trace.lineJoinStyle = .round
    trace.move(to: NSPoint(x: 200 * s, y: 512 * s))
    trace.line(to: NSPoint(x: 340 * s, y: 512 * s))
    trace.line(to: NSPoint(x: 420 * s, y: 710 * s))
    trace.line(to: NSPoint(x: 540 * s, y: 310 * s))
    trace.line(to: NSPoint(x: 635 * s, y: 560 * s))
    trace.line(to: NSPoint(x: 705 * s, y: 512 * s))
    trace.line(to: NSPoint(x: 824 * s, y: 512 * s))
    emerald.setStroke()
    trace.stroke()

    for center in [NSPoint(x: 220 * s, y: 512 * s), NSPoint(x: 804 * s, y: 512 * s)] {
        let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 42 * s, y: center.y - 42 * s, width: 84 * s, height: 84 * s))
        brightEmerald.setFill()
        dot.fill()
    }

    let branchDot = NSBezierPath(ovalIn: NSRect(x: (540 - 34) * s, y: (310 - 34) * s, width: 68 * s, height: 68 * s))
    NSColor(red: 167.0 / 255.0, green: 139.0 / 255.0, blue: 250.0 / 255.0, alpha: 1.0).setFill()
    branchDot.fill()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Cannot encode PNG")
    }
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try png.write(to: destination, options: .atomic)
}

let dir = URL(fileURLWithPath: CommandLine.arguments[1]).deletingLastPathComponent()
try renderIcon(pixelSize: 1024, to: URL(fileURLWithPath: CommandLine.arguments[1]))
try renderIcon(pixelSize: 512, to: dir.appendingPathComponent("AppIcon-512.png"))
