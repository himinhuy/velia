#!/usr/bin/env swift
// Generates Velia's app-icon PNGs (primary rose ring + an abstract neutral "disguise" icon).
// Run: swift scripts/make_icons.swift   → writes into App/Resources/.
import AppKit

func render(size: CGFloat, _ draw: (CGContext, CGFloat) -> Void) -> Data {
    let px = Int(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    draw(ctx.cgContext, size)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func fill(_ ctx: CGContext, _ size: CGFloat, _ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
    ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
}

// Primary: warm rose background + a white cycle ring (matches the in-app ring).
func primary(_ ctx: CGContext, _ s: CGFloat) {
    fill(ctx, s, 0.79, 0.36, 0.42)
    let lw = s * 0.085
    let inset = s * 0.27
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    ctx.setLineWidth(lw)
    ctx.setLineCap(.round)
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    // ~300° arc to echo the cycle wheel.
    ctx.addArc(center: CGPoint(x: s/2, y: s/2), radius: rect.width/2,
               startAngle: .pi * 0.65, endAngle: .pi * 0.35, clockwise: false)
    ctx.strokePath()
    // ovulation-style dot
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    let dot = s * 0.07
    ctx.fillEllipse(in: CGRect(x: s/2 - dot/2, y: inset - dot/2, width: dot, height: dot))
}

// Neutral "disguise": charcoal background + abstract muted dot-grid (generic, not a clone of any app).
func neutral(_ ctx: CGContext, _ s: CGFloat) {
    fill(ctx, s, 0.14, 0.15, 0.17)
    ctx.setFillColor(CGColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1))
    let r = s * 0.085
    let gap = s * 0.20
    let cx = s/2, cy = s/2
    for dx in [-gap/2, gap/2] {
        for dy in [-gap/2, gap/2] {
            ctx.fillEllipse(in: CGRect(x: cx + dx - r/2, y: cy + dy - r/2, width: r, height: r))
        }
    }
}

let fm = FileManager.default
let base = fm.currentDirectoryPath
let appIconDir = "\(base)/App/Resources/Assets.xcassets/AppIcon.appiconset"
let altDir = "\(base)/App/Resources/AltIcons"
try? fm.createDirectory(atPath: appIconDir, withIntermediateDirectories: true)
try? fm.createDirectory(atPath: altDir, withIntermediateDirectories: true)

try render(size: 1024, primary).write(to: URL(fileURLWithPath: "\(appIconDir)/icon_1024.png"))
try render(size: 120, neutral).write(to: URL(fileURLWithPath: "\(altDir)/AltNeutral@2x.png"))
try render(size: 180, neutral).write(to: URL(fileURLWithPath: "\(altDir)/AltNeutral@3x.png"))
print("✓ icons written")
