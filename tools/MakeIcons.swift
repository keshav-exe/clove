#!/usr/bin/env swift
import AppKit
import Foundation

// Draws the Clove mark — a clove bud seen from above: four sepals around a
// round crown — and writes every icon asset from the same geometry:
//
//   Clove/clove.icon/Assets/{sepals,crown}.svg   Icon Composer layers
//   Clove/Assets.xcassets/AppIcon.appiconset     fallback PNGs
//   Clove/Assets.xcassets/MenuBarIcon.imageset   template glyph
//   tools/assets/clove-mark.png                  1024px preview for docs
//
//   swift tools/MakeIcons.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("Clove/Assets.xcassets")
let iconAssets = root.appendingPathComponent("Clove/clove.icon/Assets")

// Geometry on a 1024 canvas, centered.
let sepalLength = 392.0
let sepalWidth = 228.0
let sepalBase = 40.0
let crownRadius = 116.0
let sepalAngles = [45.0, 135.0, 225.0, 315.0]

// Clove, from bark to bloom.
let paper = (top: NSColor(srgbRed: 0.98, green: 0.95, blue: 0.91, alpha: 1),
             bottom: NSColor(srgbRed: 0.93, green: 0.87, blue: 0.80, alpha: 1))
let sepalColor = (tip: NSColor(srgbRed: 0.66, green: 0.28, blue: 0.18, alpha: 1),
                  base: NSColor(srgbRed: 0.37, green: 0.13, blue: 0.09, alpha: 1))
let crownColor = (light: NSColor(srgbRed: 0.96, green: 0.75, blue: 0.55, alpha: 1),
                  dark: NSColor(srgbRed: 0.81, green: 0.44, blue: 0.20, alpha: 1))

/// One sepal pointing up from the center, in a y-up coordinate space.
func sepalControlPoints() -> [(Double, Double)] {
    [
        (sepalWidth * 0.62, sepalLength * 0.18),
        (sepalWidth * 0.42, sepalLength * 0.80),
        (0, sepalLength),
        (-sepalWidth * 0.42, sepalLength * 0.80),
        (-sepalWidth * 0.62, sepalLength * 0.18),
        (0, sepalBase),
    ]
}

func sepalPath(angle: Double, center: NSPoint, scale: Double) -> NSBezierPath {
    let p = sepalControlPoints()
    let path = NSBezierPath()
    func point(_ xy: (Double, Double)) -> NSPoint {
        NSPoint(x: center.x + xy.0 * scale, y: center.y + xy.1 * scale)
    }
    path.move(to: point((0, sepalBase)))
    path.curve(to: point(p[2]), controlPoint1: point(p[0]), controlPoint2: point(p[1]))
    path.curve(to: point(p[5]), controlPoint1: point(p[3]), controlPoint2: point(p[4]))
    path.close()

    var transform = AffineTransform()
    transform.translate(x: center.x, y: center.y)
    transform.rotate(byDegrees: -angle)
    transform.translate(x: -center.x, y: -center.y)
    path.transform(using: transform)
    return path
}

/// SVG uses y-down, so the sepal points along -y.
func sepalSVG(angle: Double, fill: String) -> String {
    let p = sepalControlPoints().map { ($0.0, -$0.1) }
    func f(_ v: Double) -> String { String(Int(v.rounded())) }
    let d = "M 0 \(f(-sepalBase)) C \(f(p[0].0)) \(f(p[0].1)), \(f(p[1].0)) \(f(p[1].1)), \(f(p[2].0)) \(f(p[2].1)) "
        + "C \(f(p[3].0)) \(f(p[3].1)), \(f(p[4].0)) \(f(p[4].1)), 0 \(f(-sepalBase)) Z"
    return "<path d=\"\(d)\" transform=\"translate(512 512) rotate(\(Int(angle)))\" fill=\"\(fill)\"/>"
}

func svgDocument(_ body: String) -> String {
    "<svg width=\"1024\" height=\"1024\" viewBox=\"0 0 1024 1024\" fill=\"none\" xmlns=\"http://www.w3.org/2000/svg\">\(body)</svg>\n"
}

// MARK: - Drawing

@MainActor
func renderPNG(size: Int, draw: (NSRect) -> Void) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }

    NSGraphicsContext.saveGraphicsState()
    if let context = NSGraphicsContext(bitmapImageRep: rep) {
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        draw(NSRect(x: 0, y: 0, width: size, height: size))
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

/// The full-color mark inside `rect`, which stands in for the 1024 canvas.
@MainActor
func drawMark(in rect: NSRect) {
    let scale = rect.width / 1024
    let center = NSPoint(x: rect.midX, y: rect.midY)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(srgbRed: 0.23, green: 0.07, blue: 0.04, alpha: 0.30)
    shadow.shadowOffset = NSSize(width: 0, height: -10 * scale)
    shadow.shadowBlurRadius = 24 * scale

    for angle in sepalAngles {
        let path = sepalPath(angle: angle, center: center, scale: scale)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        sepalColor.base.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        let gradient = NSGradient(starting: sepalColor.base, ending: sepalColor.tip)
        gradient?.draw(in: path, angle: 90 - angle)
        NSGraphicsContext.restoreGraphicsState()
    }

    let crownRect = NSRect(
        x: center.x - crownRadius * scale, y: center.y - crownRadius * scale,
        width: crownRadius * 2 * scale, height: crownRadius * 2 * scale
    )
    let crown = NSBezierPath(ovalIn: crownRect)
    NSGraphicsContext.saveGraphicsState()
    shadow.set()
    crownColor.dark.setFill()
    crown.fill()
    NSGraphicsContext.restoreGraphicsState()
    let crownGradient = NSGradient(starting: crownColor.light, ending: crownColor.dark)
    crownGradient?.draw(in: crown, relativeCenterPosition: NSPoint(x: -0.3, y: 0.35))
}

/// A macOS icon: the rounded-square body on the standard 1024 grid, with the mark on paper.
@MainActor
func drawAppIcon(in rect: NSRect) {
    let body = rect.insetBy(dx: rect.width * 100 / 1024, dy: rect.height * 100 / 1024)
    let shape = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)

    NSGraphicsContext.saveGraphicsState()
    let drop = NSShadow()
    drop.shadowColor = NSColor(white: 0, alpha: 0.28)
    drop.shadowOffset = NSSize(width: 0, height: -rect.height * 0.012)
    drop.shadowBlurRadius = rect.height * 0.025
    drop.set()
    paper.bottom.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(starting: paper.top, ending: paper.bottom)?.draw(in: body, angle: 270)
    drawMark(in: body)
    NSGraphicsContext.restoreGraphicsState()
}

/// One-color glyph for the menu bar, with a gap cut around the crown so it
/// still reads at 18 points.
@MainActor
func drawMenuBarGlyph(in rect: NSRect) {
    let scale = rect.width / 1024 * 1.12
    let center = NSPoint(x: rect.midX, y: rect.midY)
    NSColor.black.setFill()
    for angle in sepalAngles {
        sepalPath(angle: angle, center: center, scale: scale).fill()
    }
    let gap = (crownRadius + 34) * scale
    NSGraphicsContext.current?.compositingOperation = .clear
    NSBezierPath(ovalIn: NSRect(x: center.x - gap, y: center.y - gap, width: gap * 2, height: gap * 2)).fill()
    NSGraphicsContext.current?.compositingOperation = .sourceOver
    let radius = (crownRadius + 6) * scale
    NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)).fill()
}

// MARK: - Output

@MainActor
func write(_ data: Data?, to url: URL) {
    guard let data else { return }
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: url)
}

@MainActor
func run() {
    // Icon Composer layers: flat fills, so the system adds glass, light, and dark/tinted looks.
    // Gradients run along each sepal (its local -y), lighter at the tip.
    let sepalGradient = "<linearGradient id=\"sepal\" x1=\"0\" y1=\"\(Int(-sepalLength))\" x2=\"0\" y2=\"0\" gradientUnits=\"userSpaceOnUse\">"
        + "<stop stop-color=\"#A8452E\"/><stop offset=\"1\" stop-color=\"#6A2419\"/></linearGradient>"
    let sepals = sepalAngles.map { sepalSVG(angle: $0, fill: "url(#sepal)") }.joined()
    write(Data(svgDocument("<defs>\(sepalGradient)</defs>" + sepals).utf8), to: iconAssets.appendingPathComponent("sepals.svg"))
    let crownGradient = "<radialGradient id=\"crown\" cx=\"478\" cy=\"470\" r=\"\(Int(crownRadius * 1.4))\" gradientUnits=\"userSpaceOnUse\">"
        + "<stop stop-color=\"#F3B985\"/><stop offset=\"1\" stop-color=\"#D06F33\"/></radialGradient>"
    let crown = "<defs>\(crownGradient)</defs><circle cx=\"512\" cy=\"512\" r=\"\(Int(crownRadius))\" fill=\"url(#crown)\"/>"
    write(Data(svgDocument(crown).utf8), to: iconAssets.appendingPathComponent("crown.svg"))

    let appSet = catalog.appendingPathComponent("AppIcon.appiconset")
    let sizes: [(Int, String)] = [
        (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
    ]
    var rendered: [Int: Data] = [:]
    for (edge, filename) in sizes {
        let png = rendered[edge] ?? renderPNG(size: edge, draw: drawAppIcon)
        rendered[edge] = png
        write(png, to: appSet.appendingPathComponent(filename))
    }
    write(rendered[1024], to: root.appendingPathComponent("tools/assets/clove-mark.png"))

    let menuSet = catalog.appendingPathComponent("MenuBarIcon.imageset")
    write(renderPNG(size: 18, draw: drawMenuBarGlyph), to: menuSet.appendingPathComponent("MenuBarIcon.png"))
    write(renderPNG(size: 36, draw: drawMenuBarGlyph), to: menuSet.appendingPathComponent("MenuBarIcon@2x.png"))

    print("Wrote clove.icon layers, AppIcon, MenuBarIcon, and tools/assets/clove-mark.png.")
}

MainActor.assumeIsolated {
    run()
}
