#!/usr/bin/env swift
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Génère le logo du launch screen BamPocket : la pastille verte « pochette » portant le « B »,
// sur fond transparent, en @1x/@2x/@3x. Posé par le launch screen sur un fond sombre (DA).
//
// Usage : swift scripts/icon/generate_launch_logo.swift <chemin-imageset>
// (par défaut : BambuddyPocket/Resources/Assets.xcassets/LaunchLogo.imageset)

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let accent = CGColor(red: 0x00 / 255.0, green: 0xAE / 255.0, blue: 0x42 / 255.0, alpha: 1)
let accentLight = CGColor(red: 0x00 / 255.0, green: 0xC6 / 255.0, blue: 0x4D / 255.0, alpha: 1)
let dark = CGColor(red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x16 / 255.0, alpha: 1)
let colorSpace = CGColorSpaceCreateDeviceRGB()

func drawLogo(in ctx: CGContext, size: CGFloat) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let platePath = CGPath(
        roundedRect: rect,
        cornerWidth: size * 0.30,
        cornerHeight: size * 0.30,
        transform: nil
    )
    ctx.saveGState()
    ctx.addPath(platePath)
    ctx.clip()
    if let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [accentLight, accent] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size, y: 0),
            options: []
        )
    }
    ctx.restoreGState()
    drawLetterB(in: ctx, plate: rect)
}

func drawLetterB(in ctx: CGContext, plate: CGRect) {
    let glyphHeight = plate.height * 0.54
    let glyphWidth = glyphHeight * 0.66
    let originX = plate.midX - glyphWidth / 2
    let originY = plate.midY - glyphHeight / 2
    let stem = glyphWidth * 0.32
    let thickness = stem * 0.95
    let bowlGap = glyphHeight * 0.06
    let bowlHeight = (glyphHeight - bowlGap) / 2
    let bowlRight = originX + glyphWidth

    ctx.saveGState()
    ctx.setFillColor(dark)
    let filled = CGMutablePath()
    let stemRect = CGRect(x: originX, y: originY, width: stem, height: glyphHeight)
    filled.addRoundedRect(in: stemRect, cornerWidth: stem * 0.30, cornerHeight: stem * 0.30)

    func bowlOuterRect(bottom: CGFloat) -> CGRect {
        let left = originX + stem * 0.45
        return CGRect(x: left, y: bottom, width: bowlRight - left, height: bowlHeight)
    }
    let topRect = bowlOuterRect(bottom: originY + bowlHeight + bowlGap)
    let bottomRect = bowlOuterRect(bottom: originY)
    filled.addRoundedRect(in: topRect, cornerWidth: topRect.height / 2, cornerHeight: topRect.height / 2)
    filled.addRoundedRect(
        in: bottomRect,
        cornerWidth: bottomRect.height / 2,
        cornerHeight: bottomRect.height / 2
    )

    func counterRect(_ outer: CGRect) -> CGRect {
        let left = originX + stem
        return CGRect(
            x: left + thickness * 0.15,
            y: outer.minY + thickness,
            width: outer.maxX - left - thickness * 1.15,
            height: outer.height - thickness * 2
        )
    }
    let counters = CGMutablePath()
    for outer in [topRect, bottomRect] {
        let counter = counterRect(outer)
        guard counter.width > 0, counter.height > 0 else { continue }
        let radius = counter.height / 2
        counters.addRoundedRect(in: counter, cornerWidth: radius, cornerHeight: radius)
    }

    ctx.addPath(filled)
    ctx.fillPath(using: .winding)
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(counters)
    ctx.clip()
    if let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [accentLight, accent] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: plate.minX, y: plate.maxY),
            end: CGPoint(x: plate.maxX, y: plate.minY),
            options: []
        )
    }
    ctx.restoreGState()
}

func renderPNG(size: CGFloat, to url: URL) {
    let pixels = Int(size)
    guard let ctx = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { exit(1) }
    ctx.interpolationQuality = .high
    drawLogo(in: ctx, size: size)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(
              url as CFURL, UTType.png.identifier as CFString, 1, nil
          )
    else { exit(1) }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let arguments = CommandLine.arguments
let defaultSet = "BambuddyPocket/Resources/Assets.xcassets/LaunchLogo.imageset"
let setURL = URL(fileURLWithPath: arguments.count > 1 ? arguments[1] : defaultSet)
try? FileManager.default.createDirectory(at: setURL, withIntermediateDirectories: true)

/// Logo de base 240 pt (≈ taille visible centrale du launch screen).
let base = 240
renderPNG(size: CGFloat(base), to: setURL.appendingPathComponent("launch-logo.png"))
renderPNG(size: CGFloat(base * 2), to: setURL.appendingPathComponent("launch-logo@2x.png"))
renderPNG(size: CGFloat(base * 3), to: setURL.appendingPathComponent("launch-logo@3x.png"))
print("✅ launch-logo @1x/@2x/@3x générés dans \(setURL.path)")
