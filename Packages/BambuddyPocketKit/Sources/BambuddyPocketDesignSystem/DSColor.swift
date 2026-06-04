// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif

/// Palette sémantique adaptative de Bambuddy Pocket.
///
/// Reprend la direction artistique du frontend web amont (`tailwind.config.js` /
/// `src/index.css`) : accent vert constant clair/sombre, statuts sémantiques fixes,
/// et surfaces/textes qui basculent entre le thème clair (fond `#F5F5F5`) et le thème
/// sombre iconique Bambu (fond `#1A1A1A`). Les couleurs adaptatives sont construites
/// via un fournisseur dynamique `UIColor` afin de suivre le mode système sans dépendre
/// d'un catalogue d'assets côté paquet SPM.
public enum DSColor {
    // MARK: Accent (constant clair/sombre)

    /// Accent principal de la marque (vert Bambu `#00AE42`).
    public static let accent = solid(0x00AE42)
    /// Variante claire de l'accent (`#00C64D`), pour survols/dégradés.
    public static let accentLight = solid(0x00C64D)
    /// Variante sombre de l'accent (`#009438`), pour états pressés.
    public static let accentDark = solid(0x009438)

    // MARK: Statuts sémantiques (constants)

    /// Succès / en ligne / OK (`#22C55E`).
    public static let statusOK = solid(0x22C55E)
    /// Erreur / hors ligne / échec (`#EF4444`).
    public static let statusError = solid(0xEF4444)
    /// Avertissement (`#F59E0B`).
    public static let statusWarning = solid(0xF59E0B)

    // MARK: Surfaces (adaptatives)

    /// Fond d'écran principal (clair `#F5F5F5` / sombre `#1A1A1A`).
    public static let background = adaptive(light: 0xF5F5F5, dark: 0x1A1A1A)
    /// Surface de carte (clair `#FFFFFF` / sombre `#2D2D2D`).
    public static let card = adaptive(light: 0xFFFFFF, dark: 0x2D2D2D)
    /// Surface tertiaire / remplissage (clair `#E5E5E5` / sombre `#3D3D3D`).
    public static let surfaceTertiary = adaptive(light: 0xE5E5E5, dark: 0x3D3D3D)
    /// Bordure fine (clair `#D4D4D4` / sombre `#3D3D3D`).
    public static let border = adaptive(light: 0xD4D4D4, dark: 0x3D3D3D)

    // MARK: Textes (adaptatifs)

    /// Texte primaire (clair `#1A1A1A` / sombre `#FFFFFF`).
    public static let textPrimary = adaptive(light: 0x1A1A1A, dark: 0xFFFFFF)
    /// Texte secondaire (clair `#4A4A4A` / sombre `#A0A0A0`).
    public static let textSecondary = adaptive(light: 0x4A4A4A, dark: 0xA0A0A0)
    /// Texte atténué (clair `#6B6B6B` / sombre `#808080`).
    public static let textMuted = adaptive(light: 0x6B6B6B, dark: 0x808080)
    /// Texte tertiaire / très atténué (clair `#808080` / sombre `#4A4A4A`).
    public static let textTertiary = adaptive(light: 0x808080, dark: 0x4A4A4A)

    // MARK: Fabriques

    /// Construit une couleur fixe (identique en clair et en sombre) depuis un code `0xRRGGBB`.
    static func solid(_ rgb: UInt32) -> Color {
        Color(red: channel(rgb, 16), green: channel(rgb, 8), blue: channel(rgb, 0))
    }

    /// Construit une couleur adaptative depuis deux codes `0xRRGGBB` (clair / sombre).
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
            Color(UIColor { traits in
                traits.userInterfaceStyle == .dark ? uiColor(dark) : uiColor(light)
            })
        #else
            solid(light)
        #endif
    }

    private static func channel(_ rgb: UInt32, _ shift: UInt32) -> Double {
        Double((rgb >> shift) & 0xFF) / 255
    }

    #if canImport(UIKit)
        private static func uiColor(_ rgb: UInt32) -> UIColor {
            UIColor(
                red: channel(rgb, 16),
                green: channel(rgb, 8),
                blue: channel(rgb, 0),
                alpha: 1
            )
        }
    #endif
}
