import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "Resources/AControl.iconset"
let outputURL = URL(fileURLWithPath: outputPath)
try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let variants: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, pixels) in variants {
    let rep = drawIcon(size: pixels)
    let url = outputURL.appendingPathComponent(name)
    guard let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(name)")
    }
    try png.write(to: url, options: .atomic)
}

func drawIcon(size pixels: Int) -> NSBitmapImageRep {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
        fatalError("Could not create bitmap context")
    }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.setShouldAntialias(true)

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let margin = size * 0.072
    let tile = NSRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
    let radius = size * 0.215
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0.10, alpha: 0.20)
    shadow.shadowBlurRadius = size * 0.060
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.026)

    NSGraphicsContext.current?.saveGraphicsState()
    shadow.set()
    NSColor(calibratedWhite: 0.0, alpha: 0.12).setFill()
    tilePath.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    let gradient = NSGradient(colors: [
        NSColor(red: 0.96, green: 0.99, blue: 1.00, alpha: 1.0),
        NSColor(red: 0.82, green: 0.95, blue: 1.00, alpha: 1.0),
        NSColor(red: 0.95, green: 0.88, blue: 1.00, alpha: 1.0)
    ])
    gradient?.draw(in: tilePath, angle: 132)

    let tintWash = NSGradient(colors: [
        NSColor(red: 0.10, green: 0.72, blue: 0.96, alpha: 0.28),
        NSColor(red: 0.84, green: 0.22, blue: 0.92, alpha: 0.15),
        NSColor(red: 0.21, green: 0.97, blue: 0.68, alpha: 0.14)
    ])
    tintWash?.draw(in: tilePath, angle: 38)

    let inner = tile.insetBy(dx: size * 0.022, dy: size * 0.022)
    let innerPath = NSBezierPath(roundedRect: inner, xRadius: radius * 0.88, yRadius: radius * 0.88)
    NSColor.white.withAlphaComponent(0.48).setStroke()
    innerPath.lineWidth = max(1, size * 0.010)
    innerPath.stroke()

    let glowRect = NSRect(x: tile.minX + size * 0.12, y: tile.minY + size * 0.15, width: tile.width * 0.76, height: tile.height * 0.72)
    let glow = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.55),
        NSColor.white.withAlphaComponent(0.08)
    ])
    glow?.draw(in: NSBezierPath(ovalIn: glowRect), relativeCenterPosition: NSPoint(x: -0.22, y: 0.22))

    let glassPane = NSRect(x: tile.minX + size * 0.135, y: tile.minY + size * 0.155, width: tile.width - size * 0.27, height: tile.height - size * 0.31)
    let panePath = NSBezierPath(roundedRect: glassPane, xRadius: size * 0.150, yRadius: size * 0.150)
    NSColor.white.withAlphaComponent(0.44).setFill()
    panePath.fill()
    NSColor(red: 0.08, green: 0.46, blue: 0.68, alpha: 0.16).setStroke()
    panePath.lineWidth = max(1, size * 0.007)
    panePath.stroke()

    let display = NSRect(x: glassPane.minX + size * 0.095, y: glassPane.minY + size * 0.105, width: glassPane.width - size * 0.19, height: size * 0.155)
    let displayPath = NSBezierPath(roundedRect: display, xRadius: size * 0.056, yRadius: size * 0.056)
    NSColor(red: 0.02, green: 0.04, blue: 0.06, alpha: 0.84).setFill()
    displayPath.fill()
    NSColor.white.withAlphaComponent(0.22).setStroke()
    displayPath.lineWidth = max(1, size * 0.0055)
    displayPath.stroke()

    drawCenteredText(
        "A",
        font: NSFont.systemFont(ofSize: size * 0.375, weight: .black),
        color: NSColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 0.92),
        rect: NSRect(x: 0, y: size * 0.420, width: size, height: size * 0.35)
    )

    drawText(
        "❯",
        font: NSFont.monospacedSystemFont(ofSize: size * 0.100, weight: .bold),
        color: NSColor(red: 0.18, green: 0.92, blue: 0.70, alpha: 0.98),
        rect: NSRect(x: display.minX + size * 0.044, y: display.minY + size * 0.015, width: size * 0.12, height: display.height)
    )
    drawText(
        "A",
        font: NSFont.monospacedSystemFont(ofSize: size * 0.088, weight: .bold),
        color: NSColor(red: 0.82, green: 0.94, blue: 1.00, alpha: 0.98),
        rect: NSRect(x: display.minX + size * 0.145, y: display.minY + size * 0.027, width: size * 0.10, height: display.height)
    )

    let dotRadius = size * 0.018
    let dotY = display.midY
    for index in 0..<3 {
        let x = display.maxX - size * (0.070 + CGFloat(index) * 0.042)
        NSColor.white.withAlphaComponent(index == 0 ? 0.76 : 0.40).setFill()
        NSBezierPath(ovalIn: NSRect(x: x - dotRadius, y: dotY - dotRadius, width: dotRadius * 2, height: dotRadius * 2)).fill()
    }

    let routeStart = CGPoint(x: glassPane.minX + size * 0.140, y: glassPane.maxY - size * 0.120)
    let routeMid = CGPoint(x: glassPane.maxX - size * 0.235, y: glassPane.maxY - size * 0.128)
    let routeEnd = CGPoint(x: glassPane.maxX - size * 0.135, y: glassPane.maxY - size * 0.210)
    let route = NSBezierPath()
    route.move(to: routeStart)
    route.curve(to: routeEnd, controlPoint1: CGPoint(x: routeStart.x + size * 0.20, y: routeStart.y + size * 0.060), controlPoint2: routeMid)
    NSColor(red: 0.03, green: 0.61, blue: 0.94, alpha: 0.34).setStroke()
    route.lineCapStyle = .round
    route.lineWidth = max(1, size * 0.018)
    route.stroke()

    drawNode(center: routeStart, radius: size * 0.033, color: NSColor(red: 0.03, green: 0.72, blue: 0.96, alpha: 0.95))
    drawNode(center: routeEnd, radius: size * 0.039, color: NSColor(red: 0.78, green: 0.25, blue: 0.86, alpha: 0.92))

    let highlight = NSBezierPath()
    highlight.move(to: CGPoint(x: tile.minX + size * 0.13, y: tile.maxY - size * 0.145))
    highlight.curve(to: CGPoint(x: tile.maxX - size * 0.22, y: tile.maxY - size * 0.090), controlPoint1: CGPoint(x: tile.minX + size * 0.30, y: tile.maxY - size * 0.025), controlPoint2: CGPoint(x: tile.maxX - size * 0.35, y: tile.maxY - size * 0.040))
    NSColor.white.withAlphaComponent(0.28).setStroke()
    highlight.lineCapStyle = .round
    highlight.lineWidth = max(1, size * 0.020)
    highlight.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func drawCenteredText(_ text: String, font: NSFont, color: NSColor, rect: NSRect) {
    drawText(text, font: font, color: color, rect: rect, alignment: .center)
}

func drawText(_ text: String, font: NSFont, color: NSColor, rect: NSRect, alignment: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    let string = NSAttributedString(string: text, attributes: attributes)
    let textSize = string.size()
    let drawRect = NSRect(
        x: rect.minX,
        y: rect.midY - textSize.height / 2,
        width: rect.width,
        height: textSize.height
    )
    string.draw(in: drawRect)
}

func drawNode(center: CGPoint, radius: CGFloat, color: NSColor) {
    let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    color.setFill()
    NSBezierPath(ovalIn: rect).fill()
    NSColor.white.withAlphaComponent(0.75).setStroke()
    let ring = NSBezierPath(ovalIn: rect.insetBy(dx: radius * 0.20, dy: radius * 0.20))
    ring.lineWidth = max(1, radius * 0.18)
    ring.stroke()
}
