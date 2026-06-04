// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

/// Espacements normalisés (en points).
public enum DSSpacing {
    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
}

/// Rayons d'arrondi normalisés (DA Bambuddy : cartes `rounded-lg` ~12pt, pastilles `rounded-full`).
public enum DSRadius {
    public static let small: CGFloat = 8
    public static let card: CGFloat = 12
    public static let large: CGFloat = 16
    /// Rayon « plein » pour badges/pastilles (`rounded-full`).
    public static let pill: CGFloat = 999
}

/// Épaisseurs de bordure normalisées.
public enum DSBorder {
    /// Bordure fine standard (1pt) des cartes/séparateurs.
    public static let thin: CGFloat = 1
}
