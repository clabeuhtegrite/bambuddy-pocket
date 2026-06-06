// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Génère un **G-code de démonstration** rendu en tracé d'outil par le viewer 3D (`viewer.html`).
/// Dessine un cylindre nervuré couche par couche (extrusions G1 avec E croissant) afin d'obtenir
/// un aperçu vert dense et esthétique. Purement synthétique, aucune donnée réelle.
enum DemoToolpath {
    /// G-code complet (en-tête absolu G90/M82 + couches concentriques).
    static let gcode: String = build()

    private static func build() -> String {
        let centerX = 110.0
        let centerY = 110.0
        let baseRadius = 28.0
        let layerHeight = 0.2
        let layers = 90
        let segments = 96
        var extrusion = 0.0
        // Déplacement initial (G0, sans extrusion) jusqu'au point de départ, pour éviter un
        // segment d'extrusion parasite depuis l'origine.
        let startX = centerX + baseRadius
        var lines: [String] = ["G90", "M82", "G21", "G0 X\(startX) Y\(centerY) Z\(layerHeight)"]

        // Hélice continue (mode « vase ») : Z monte progressivement à chaque segment, sans saut
        // de couche — d'où un tracé d'extrusion ininterrompu, sans déplacement parasite.
        let totalSegments = layers * segments
        for step in 0 ... totalSegments {
            let angle = (Double(step) / Double(segments)) * 2.0 * Double.pi
            let z = layerHeight + (Double(step) / Double(segments)) * layerHeight
            // Léger profil « vase » : rayon qui ondule avec la hauteur.
            let wave = 1.0 + 0.12 * sin(Double(step) / Double(segments) / 6.0 * 2.0 * Double.pi)
            let radius = baseRadius * wave
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)
            extrusion += 0.04
            let e = (extrusion * 100).rounded() / 100
            let fx = (x * 1000).rounded() / 1000
            let fy = (y * 1000).rounded() / 1000
            let fz = (z * 1000).rounded() / 1000
            lines.append("G1 X\(fx) Y\(fy) Z\(fz) E\(e)")
        }
        return lines.joined(separator: "\n")
    }
}
