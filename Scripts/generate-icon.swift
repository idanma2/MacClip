// Generates Resources/AppIcon.icns — a simple colored rounded-square with
// a white clipboard glyph, matching the "colorful but basic" aesthetic.
// Run with: swift Scripts/generate-icon.swift
import AppKit
import CoreGraphics

let size = 1024
let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let resourcesDir = scriptDir.deletingLastPathComponent().appendingPathComponent("Resources")
let iconsetDir = resourcesDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetDir)
try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

func renderMaster() -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    // Background: rounded square, blue -> teal gradient (distinct from
    // MacSecureSSH's blue -> purple, same "colorful but basic" spirit).
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.22
    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.addPath(path)
    ctx.clip()

    let colors = [CGColor(red: 0.02, green: 0.55, blue: 0.95, alpha: 1), CGColor(red: 0.0, green: 0.78, blue: 0.68, alpha: 1)]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    // Foreground: a simple clipboard glyph via SF Symbols, rendered white.
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    let config = NSImage.SymbolConfiguration(pointSize: CGFloat(size) * 0.52, weight: .medium)
    let symbol = NSImage(systemSymbolName: "doc.on.clipboard.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
    let tinted = NSImage(size: symbol.size)
    tinted.lockFocus()
    NSColor.white.set()
    let imgRect = NSRect(origin: .zero, size: symbol.size)
    symbol.draw(in: imgRect)
    imgRect.fill(using: .sourceAtop)
    tinted.unlockFocus()

    let drawRect = CGRect(
        x: (CGFloat(size) - tinted.size.width) / 2,
        y: (CGFloat(size) - tinted.size.height) / 2,
        width: tinted.size.width, height: tinted.size.height
    )
    tinted.draw(in: drawRect)
    NSGraphicsContext.restoreGraphicsState()

    return ctx.makeImage()!
}

let master = renderMaster()

func writePNG(_ image: CGImage, size px: Int, name: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: px, height: px)
    let resized = NSImage(size: NSSize(width: px, height: px))
    resized.addRepresentation(rep)

    let finalRep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: finalRep)
    resized.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()

    let data = finalRep.representation(using: .png, properties: [:])!
    try! data.write(to: iconsetDir.appendingPathComponent(name))
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png")
]
for (px, name) in sizes {
    writePNG(master, size: px, name: name)
}
print("iconset written to \(iconsetDir.path)")
