// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

/// Espacements normalisés (en points).
public enum DSSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
}

/// Rayons d'arrondi normalisés.
public enum DSRadius {
    public static let small: CGFloat = 8
    public static let card: CGFloat = 12
}

/// Couleurs sémantiques du design system.
public enum DSColor {
    public static let accent = Color.accentColor
}
