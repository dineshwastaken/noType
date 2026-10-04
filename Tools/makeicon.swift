#!/usr/bin/env swift
import AppKit
import Foundation

// Renders AppIcon.icns from code — no design tool, no binary asset to keep in sync with
// the app palette. Run: make icon

// Matches `DS.Color.accent` / `accentSoft` (light values) in DesignSystem.swift.
let deep = NSColor(srgbRed: 0x31/255.0, green: 0x2E/255.0, blue: 0x81/255.0, alpha: 1)
let accent = NSColor(srgbRed: 0x4F/255.0, green: 0x46/255.0, blue: 0xE5/255.0, alpha: 1)
let accentSoft = NSColor(srgbRed: 0x7C/255.0, green: 0x8C/255.0, blue: 0xFF/255.0, alpha: 1)
let cyan = NSColor(srgbRed: 0x5E/255.0, green: 0xD0/255.0, blue: 0xFF/255.0, alpha: 1)

/// Relative bar heights, center-weighted so the mark reads as a voice waveform rather
/// than a bar chart.
let bars: [CGFloat] = [0.28, 0.50, 0.80, 1.00, 0.72, 0.46, 0.26]

func gradient(_ colors: [NSColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors.map(\.cgColor) as CFArray,
        locations: locations
    )!
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // macOS icon grid: art occupies the middle ~82%, leaving the shadow gutter the system
    // expects.
    let inset = size * 0.09
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    // Apple's squircle is ~22.37% of the tile's edge.
    let radius = rect.width * 0.2237
    let tile = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Drop shadow under the tile.
    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.012),
        blur: size * 0.035,
        color: NSColor.black.withAlphaComponent(0.30).cgColor
    )
    ctx.addPath(tile)
    ctx.setFillColor(accent.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Background: deep indigo to periwinkle, with a cyan bloom low-right for the glass to
    // refract.
    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([accentSoft, accent, deep], [0, 0.5, 1]),
        start: CGPoint(x: rect.minX, y: rect.maxY),
        end: CGPoint(x: rect.maxX, y: rect.minY),
        options: []
    )
    ctx.drawRadialGradient(
        gradient([cyan.withAlphaComponent(0.55), cyan.withAlphaComponent(0)], [0, 1]),
        startCenter: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.2),
        startRadius: 0,
        endCenter: CGPoint(x: rect.maxX - rect.width * 0.18, y: rect.minY + rect.height * 0.2),
        endRadius: rect.width * 0.6,
        options: []
    )
    ctx.restoreGState()

    // The glass lozenge: a frosted capsule floating over the tile.
    let glassRect = rect.insetBy(dx: rect.width * 0.14, dy: rect.height * 0.30)
    let glassRadius = glassRect.height / 2
    let glass = CGPath(roundedRect: glassRect, cornerWidth: glassRadius, cornerHeight: glassRadius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.016),
        blur: size * 0.05,
        color: deep.withAlphaComponent(0.55).cgColor
    )
    ctx.addPath(glass)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.16).cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Inner sheen: brighter at the top, the way light catches the upper lip of glass.
    ctx.saveGState()
    ctx.addPath(glass)
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([NSColor.white.withAlphaComponent(0.30), NSColor.white.withAlphaComponent(0.02)], [0, 1]),
        start: CGPoint(x: glassRect.midX, y: glassRect.maxY),
        end: CGPoint(x: glassRect.midX, y: glassRect.minY),
        options: []
    )
    ctx.restoreGState()

    // Rim light: a hairline that is bright top-left and fades bottom-right.
    ctx.saveGState()
    ctx.addPath(glass)
    ctx.setLineWidth(max(1, size * 0.006))
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(
        gradient([NSColor.white.withAlphaComponent(0.9), NSColor.white.withAlphaComponent(0.15)], [0, 1]),
        start: CGPoint(x: glassRect.minX, y: glassRect.maxY),
        end: CGPoint(x: glassRect.maxX, y: glassRect.minY),
        options: []
    )
    ctx.restoreGState()

    // Waveform mark inside the glass.
    let barWidth = glassRect.height * 0.085
    let gap = glassRect.height * 0.075
    let totalWidth = CGFloat(bars.count) * barWidth + CGFloat(bars.count - 1) * gap
    let maxHeight = glassRect.height * 0.62
    var x = glassRect.midX - totalWidth / 2

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -size * 0.003),
        blur: size * 0.01,
        color: deep.withAlphaComponent(0.35).cgColor
    )
    ctx.setFillColor(NSColor.white.cgColor)
    for bar in bars {
        let height = max(barWidth, maxHeight * bar)
        let barRect = CGRect(x: x, y: glassRect.midY - height / 2, width: barWidth, height: height)
        ctx.addPath(CGPath(
            roundedRect: barRect,
            cornerWidth: barWidth / 2,
            cornerHeight: barWidth / 2,
            transform: nil
        ))
        ctx.fillPath()
        x += barWidth + gap
    }
    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func png(_ image: NSImage, pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // Redraw at native pixel size rather than scaling a single render — keeps the small
    // sizes crisp instead of muddy.
    drawIcon(size: CGFloat(pixels)).draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: .zero, operation: .sourceOver, fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = root.appendingPathComponent("Resources/AppIcon.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

// (point size, scale) pairs iconutil expects.
let variants: [(Int, Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2),
    (256, 1), (256, 2), (512, 1), (512, 2),
]

for (points, scale) in variants {
    let pixels = points * scale
    guard let data = png(NSImage(), pixels: pixels) else {
        print("failed at \(pixels)px"); exit(1)
    }
    let suffix = scale == 2 ? "@2x" : ""
    let name = "icon_\(points)x\(points)\(suffix).png"
    try data.write(to: iconset.appendingPathComponent(name))
}

print("wrote \(variants.count) PNGs to Resources/AppIcon.iconset")
