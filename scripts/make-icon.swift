import AppKit

func hexColor(_ rgb: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        red: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: alpha
    )
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let outer = rect.insetBy(dx: size * 0.045, dy: size * 0.045)

    // drop shadow
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
    shadow.shadowBlurRadius = size * 0.06
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.025)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()

    let squircle = NSBezierPath(roundedRect: outer, xRadius: size * 0.2237, yRadius: size * 0.2237)
    let gradient = NSGradient(colors: [
        hexColor(0x4E7BFF),
        hexColor(0x7A4BF6),
        hexColor(0x9B3EF0)
    ])!
    gradient.draw(in: squircle, angle: 135)
    NSGraphicsContext.restoreGraphicsState()

    // top-to-bottom sheen, smooth across the whole face
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    let sheen = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.30),
        NSColor.white.withAlphaComponent(0.0),
        NSColor.black.withAlphaComponent(0.16)
    ])!
    sheen.draw(in: outer, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // gauge
    let center = NSPoint(x: rect.midX, y: rect.height * 0.40)
    let radius = size * 0.30
    let start: CGFloat = 210
    let end: CGFloat = -30
    let value: CGFloat = 0.72
    let progressEnd = start - (start - end) * value

    let line = size * 0.085
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()

    let track = NSBezierPath()
    track.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: end, clockwise: true)
    track.lineWidth = line
    track.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.28).setStroke()
    track.stroke()

    let progress = NSBezierPath()
    progress.appendArc(withCenter: center, radius: radius, startAngle: start, endAngle: progressEnd, clockwise: true)
    progress.lineWidth = line
    progress.lineCapStyle = .round
    NSColor.white.setStroke()
    progress.stroke()

    // needle
    let needleLength = radius - line * 0.55
    let rad = progressEnd * .pi / 180
    let tip = NSPoint(x: center.x + cos(rad) * needleLength, y: center.y + sin(rad) * needleLength)
    let needle = NSBezierPath()
    needle.move(to: center)
    needle.line(to: tip)
    needle.lineWidth = size * 0.055
    needle.lineCapStyle = .round
    NSColor.white.setStroke()
    needle.stroke()

    // center hub
    let hub = NSBezierPath(ovalIn: NSRect(x: center.x - size * 0.055, y: center.y - size * 0.055,
                                          width: size * 0.11, height: size * 0.11))
    NSColor.white.setFill()
    hub.fill()
    let inner = NSBezierPath(ovalIn: NSRect(x: center.x - size * 0.022, y: center.y - size * 0.022,
                                            width: size * 0.044, height: size * 0.044))
    hexColor(0x5A46F0).setFill()
    inner.fill()
    NSGraphicsContext.restoreGraphicsState()

    // rim
    let rim = NSBezierPath(roundedRect: outer, xRadius: size * 0.2237, yRadius: size * 0.2237)
    rim.lineWidth = size * 0.014
    NSColor.white.withAlphaComponent(0.22).setStroke()
    rim.stroke()

    return image
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dist/GlmUsageBar.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: outputDir)
try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let names: [(Int, String)] = [
    (16, "16"), (32, "16x16@2x"),
    (32, "32"), (64, "32x32@2x"),
    (128, "128"), (256, "128x128@2x"),
    (256, "256"), (512, "256x256@2x"),
    (512, "512"), (1024, "512x512@2x")
]

for (px, name) in names {
    let img = drawIcon(size: CGFloat(px))
    let tiff = img.tiffRepresentation!
    let rep = NSBitmapImageRep(data: tiff)!
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: URL(fileURLWithPath: "\(outputDir)/icon_\(name).png"))
}

// preview
let preview = drawIcon(size: 512)
let png = NSBitmapImageRep(data: preview.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: "/tmp/glm_icon_preview.png"))
print("done: \(outputDir)")
