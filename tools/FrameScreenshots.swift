#!/usr/bin/env swift
// Puts raw window captures on Clove's warm backdrop: rounded corners, a soft
// shadow, and room to breathe. For the README and the website.
//
//   swift tools/FrameScreenshots.swift docs/screenshots docs/screenshots/framed

import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    print("Usage: swift tools/FrameScreenshots.swift <input folder> <output folder>")
    exit(1)
}
let input = URL(filePath: arguments[1])
let output = URL(filePath: arguments[2])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// The window's own corners in the capture; clipping a touch inside hides
/// whatever the capture painted behind them.
let windowRadius: CGFloat = 26
let padding: CGFloat = 112

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func frame(_ image: CGImage) -> CGImage? {
    let window = CGSize(width: image.width, height: image.height)
    let canvas = CGSize(width: window.width + padding * 2, height: window.height + padding * 2)
    guard let context = CGContext(
        data: nil,
        width: Int(canvas.width),
        height: Int(canvas.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // Backdrop: the icon's cream fading into its clay, with a soft glow up top.
    let wash = CGGradient(
        colorsSpace: nil,
        colors: [color(0xF4E6D4), color(0xE9B48C), color(0xB4532E)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(wash, start: CGPoint(x: 0, y: canvas.height), end: CGPoint(x: canvas.width, y: 0), options: [])
    let glow = CGGradient(colorsSpace: nil, colors: [color(0xFFF8EE, 0.7), color(0xFFF8EE, 0)] as CFArray, locations: [0, 1])!
    let glowCenter = CGPoint(x: canvas.width * 0.3, y: canvas.height * 0.9)
    context.drawRadialGradient(glow, startCenter: glowCenter, startRadius: 0, endCenter: glowCenter, endRadius: canvas.width * 0.6, options: [])

    let rect = CGRect(origin: CGPoint(x: padding, y: padding), size: window)
    let shape = CGPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerWidth: windowRadius, cornerHeight: windowRadius, transform: nil)

    // Two shadows: a wide soft one for lift, a tight one for contact.
    for (blur, offset, alpha) in [(CGFloat(70), CGFloat(-28), CGFloat(0.32)), (14, -4, 0.22)] {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: offset), blur: blur, color: color(0x3A1608, alpha))
        context.addPath(shape)
        context.setFillColor(color(0x1E1E1E))
        context.fillPath()
        context.restoreGState()
    }

    context.saveGState()
    context.addPath(shape)
    context.clip()
    context.draw(image, in: rect)
    context.restoreGState()

    context.addPath(shape)
    context.setStrokeColor(color(0xFFFFFF, 0.14))
    context.setLineWidth(1)
    context.strokePath()

    return context.makeImage()
}

let files = try FileManager.default.contentsOfDirectory(at: input, includingPropertiesForKeys: nil)
    .filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

for file in files {
    guard
        let source = CGImageSourceCreateWithURL(file as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
        let framed = frame(image)
    else {
        print("x Couldn't read \(file.lastPathComponent)")
        continue
    }
    let target = output.appending(path: file.deletingPathExtension().lastPathComponent + ".png")
    guard let destination = CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(destination, framed, nil)
    CGImageDestinationFinalize(destination)
    print("ok \(target.path(percentEncoded: false))")
}
