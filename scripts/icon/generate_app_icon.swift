#!/usr/bin/env swift
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Génère l'icône d'app BamPocket, de façon reproductible, en Core Graphics.
//
// Produit un master 1024×1024 PNG (sans canal alpha, comme exigé par l'App Store) ainsi que
// l'ensemble des tailles classiques de l'`AppIcon.appiconset`, chacune rendue directement en
// Core Graphics (netteté maximale plutôt qu'un simple redimensionnement).
//
// Direction artistique : fond sombre Bambu (#1A1A1A), accent vert (#00AE42). Motif : un « B »
// (BamPocket) découpé dans une pastille verte évoquant une pochette, posé sur le fond sombre.
//
// Usage :
//   swift scripts/icon/generate_app_icon.swift <chemin-AppIcon.appiconset>
// (par défaut : BambuddyPocket/Resources/Assets.xcassets/AppIcon.appiconset)

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Palette (DA BamPocket)

let backgroundTop = CGColor(red: 0x24 / 255.0, green: 0x24 / 255.0, blue: 0x24 / 255.0, alpha: 1)
let backgroundBottom = CGColor(red: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x12 / 255.0, alpha: 1)
let accent = CGColor(red: 0x00 / 255.0, green: 0xAE / 255.0, blue: 0x42 / 255.0, alpha: 1)
let accentLight = CGColor(red: 0x00 / 255.0, green: 0xC6 / 255.0, blue: 0x4D / 255.0, alpha: 1)
let dark = CGColor(red: 0x16 / 255.0, green: 0x16 / 255.0, blue: 0x16 / 255.0, alpha: 1)

let colorSpace = CGColorSpaceCreateDeviceRGB()

/// Dessine l'icône (sans coins arrondis : iOS applique son propre masque) dans `ctx`.
func drawIcon(in ctx: CGContext, size: CGFloat) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    // Fond : dégradé vertical sombre.
    if let gradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [backgroundTop, backgroundBottom] as CFArray,
        locations: [0, 1]
    ) {
        ctx.saveGState()
        ctx.addRect(rect)
        ctx.clip()
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
        ctx.restoreGState()
    }

    // Pastille verte (« pochette ») centrée, coins très arrondis.
    let inset = size * 0.17
    let plateRect = rect.insetBy(dx: inset, dy: inset)
    let plateRadius = plateRect.width * 0.30
    let platePath = CGPath(
        roundedRect: plateRect,
        cornerWidth: plateRadius,
        cornerHeight: plateRadius,
        transform: nil
    )
    // Dégradé vert sur la pastille (subtil, du haut-gauche clair vers le bas-droit).
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
            start: CGPoint(x: plateRect.minX, y: plateRect.maxY),
            end: CGPoint(x: plateRect.maxX, y: plateRect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Glyphe « B » épais découpé en sombre dans la pastille. Les contre-formes sont rebouchées
    // avec une coupe du même dégradé (clip) pour rester homogènes avec la pastille.
    drawLetterB(in: ctx, plate: plateRect, color: dark)
}

/// Dessine un « B » géométrique épais centré dans `plate`.
///
/// Construction : on remplit (even-odd) la **silhouette pleine** du B — barre verticale unie
/// aux deux bols — puis on **perce** les deux contre-formes (counters). Les bols chevauchent la
/// barre pour que le glyphe se lise comme un B connecté (et non « lo »).
func drawLetterB(in ctx: CGContext, plate: CGRect, color: CGColor) {
    let glyphHeight = plate.height * 0.54
    let glyphWidth = glyphHeight * 0.66
    let originX = plate.midX - glyphWidth / 2
    let originY = plate.midY - glyphHeight / 2
    let stem = glyphWidth * 0.32 // épaisseur de la barre verticale
    let thickness = stem * 0.95 // épaisseur des bols

    let bowlGap = glyphHeight * 0.06
    let bowlHeight = (glyphHeight - bowlGap) / 2
    let bowlRight = originX + glyphWidth

    ctx.saveGState()
    ctx.setFillColor(color)

    // 1) Silhouette pleine : barre + bols pleins (qui chevauchent la barre).
    let filled = CGMutablePath()
    let stemRect = CGRect(x: originX, y: originY, width: stem, height: glyphHeight)
    filled.addRoundedRect(in: stemRect, cornerWidth: stem * 0.30, cornerHeight: stem * 0.30)

    func bowlOuterRect(bottom: CGFloat) -> CGRect {
        // Commence à l'intérieur de la barre pour la jonction.
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

    /// 2) Contre-formes à percer (counters) — décalées à droite de la barre.
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

    // Remplit la silhouette pleine (non-zero : les chevauchements fusionnent proprement).
    ctx.addPath(filled)
    ctx.fillPath(using: .winding)
    ctx.restoreGState()

    // Perce les contre-formes : on reclippe sur les counters et on repeint le dégradé de la
    // pastille (homogène avec le fond vert).
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

/// Rend un PNG carré opaque de `size` px.
func renderPNG(size: CGFloat, to url: URL) {
    let pixels = Int(size)
    guard let ctx = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        FileHandle.standardError.write(Data("Échec création contexte CG\n".utf8))
        exit(1)
    }
    ctx.interpolationQuality = .high
    drawIcon(in: ctx, size: size)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(
              url as CFURL, UTType.png.identifier as CFString, 1, nil
          )
    else {
        FileHandle.standardError.write(Data("Échec encodage PNG\n".utf8))
        exit(1)
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

// MARK: - Sortie

let arguments = CommandLine.arguments
let defaultSet = "BambuddyPocket/Resources/Assets.xcassets/AppIcon.appiconset"
let setPath = arguments.count > 1 ? arguments[1] : defaultSet
let setURL = URL(fileURLWithPath: setPath)
try? FileManager.default.createDirectory(at: setURL, withIntermediateDirectories: true)

/// Master 1024 (universel App Store) + tailles classiques pour robustesse.
let master = setURL.appendingPathComponent("icon-1024.png")
renderPNG(size: 1024, to: master)
print("✅ icon-1024.png")

/// Tailles classiques (iPhone/iPad) : on rend directement en CG pour la netteté.
struct IconSize { let pixels: Int
    let name: String
}

let sizes: [IconSize] = [
    .init(pixels: 40, name: "icon-20@2x.png"),
    .init(pixels: 60, name: "icon-20@3x.png"),
    .init(pixels: 58, name: "icon-29@2x.png"),
    .init(pixels: 87, name: "icon-29@3x.png"),
    .init(pixels: 80, name: "icon-40@2x.png"),
    .init(pixels: 120, name: "icon-40@3x.png"),
    .init(pixels: 120, name: "icon-60@2x.png"),
    .init(pixels: 180, name: "icon-60@3x.png"),
    .init(pixels: 20, name: "icon-20.png"),
    .init(pixels: 29, name: "icon-29.png"),
    .init(pixels: 40, name: "icon-40.png"),
    .init(pixels: 152, name: "icon-76@2x.png"),
    .init(pixels: 167, name: "icon-83.5@2x.png")
]
for icon in sizes {
    renderPNG(size: CGFloat(icon.pixels), to: setURL.appendingPathComponent(icon.name))
}

print("✅ \(sizes.count) tailles classiques générées dans \(setPath)")
