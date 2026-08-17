#!/usr/bin/env swift
import AppKit
import Foundation

// Renders SVG assets into AppIcon.appiconset and MenuBarIcon.imageset.
//
//   swift tools/MakeIcons.swift

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let catalog = root.appendingPathComponent("Clove/Assets.xcassets")
let appMarkURL = root.appendingPathComponent("Clove/clove.icon/Assets/SVG Image.svg")
let menuMarkURL = root.appendingPathComponent("tools/assets/clove-menubar.svg")

// Matches Icon Composer fill from clove.icon/icon.json
let gradientTop = NSColor(displayP3Red: 0.92, green: 0.95, blue: 0.98, alpha: 1)
let gradientBottom = NSColor(displayP3Red: 0.86961, green: 0.91276, blue: 0.93555, alpha: 1)

@MainActor
func loadSVG(_ url: URL) -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        fputs("Missing SVG at \(url.path)\n", stderr)
        exit(1)
    }
    return image
}

@MainActor
func renderPNG(size: Int, draw: (NSRect) -> Void) -> Data? {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
    else { return nil }

    NSGraphicsContext.saveGraphicsState()
    if let context = NSGraphicsContext(bitmapImageRep: rep) {
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        draw(rect)
    }
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

@MainActor
func drawAppIconCanvas(in rect: NSRect, mark: NSImage) {
    let gradient = NSGradient(starting: gradientTop, ending: gradientBottom)!
    gradient.draw(in: rect, angle: 270)

    let inset = rect.width * 0.11
    let glyph = rect.insetBy(dx: inset, dy: inset)
    mark.draw(in: glyph, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

@MainActor
func drawMenuBarCanvas(in rect: NSRect, mark: NSImage) {
    NSColor.clear.setFill()
    rect.fill()

    let height = rect.height * 0.72
    let aspect = mark.size.width / mark.size.height
    let width = height * aspect
    let origin = NSPoint(x: (rect.width - width) / 2, y: (rect.height - height) / 2)
    mark.draw(in: NSRect(x: origin.x, y: origin.y, width: width, height: height), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
}

@MainActor
func writePNG(_ data: Data, to url: URL) {
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? data.write(to: url)
}

@MainActor
func run() {
    let appMark = loadSVG(appMarkURL)
    let menuMark = loadSVG(menuMarkURL)

    let appSet = catalog.appendingPathComponent("AppIcon.appiconset")
    let macSizes: [(Int, String)] = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]

    var rendered: [Int: Data] = [:]
    for (edge, filename) in macSizes {
        let png = rendered[edge] ?? renderPNG(size: edge) { rect in
            drawAppIconCanvas(in: rect, mark: appMark)
        }
        guard let png else { continue }
        rendered[edge] = png
        writePNG(png, to: appSet.appendingPathComponent(filename))
    }

    let appContents = """
    {
      "images" : [
        { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
        { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
        { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
        { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
        { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
        { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
        { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
        { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
        { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
        { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }
    """
    try? appContents.write(to: appSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

    let menuSet = catalog.appendingPathComponent("MenuBarIcon.imageset")
    if let oneX = renderPNG(size: 18, draw: { drawMenuBarCanvas(in: $0, mark: menuMark) }) {
        writePNG(oneX, to: menuSet.appendingPathComponent("MenuBarIcon.png"))
    }
    if let twoX = renderPNG(size: 36, draw: { drawMenuBarCanvas(in: $0, mark: menuMark) }) {
        writePNG(twoX, to: menuSet.appendingPathComponent("MenuBarIcon@2x.png"))
    }

    let menuContents = """
    {
      "images" : [
        { "filename" : "MenuBarIcon.png", "idiom" : "mac", "scale" : "1x" },
        { "filename" : "MenuBarIcon@2x.png", "idiom" : "mac", "scale" : "2x" }
      ],
      "info" : { "author" : "xcode", "version" : 1 },
      "properties" : { "template-rendering-intent" : "template" }
    }
    """
    try? menuContents.write(to: menuSet.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

    print("Wrote app icon and menu bar icon from clove.icon + clove-menubar.svg.")
}

MainActor.assumeIsolated {
    run()
}
