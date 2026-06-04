// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

/// Échelle typographique Bambuddy basée sur **Inter** (TTF variable, OFL).
///
/// La police est déclarée dans le bundle de l'app via `UIAppFonts` (cf. `project.yml`) ;
/// le nom de famille embarqué est « Inter ». Les helpers s'appuient sur
/// `Font.custom(_:size:relativeTo:)` afin de **rester compatibles Dynamic Type** (la
/// taille évolue avec les réglages d'accessibilité) tout en appliquant le poids voulu
/// via l'axe variable (`.weight`).
public enum DSFont {
    /// Nom de famille de la police embarquée.
    public static let family = "Inter"

    /// Construit une police Inter d'une taille et d'un poids donnés, calée sur un style
    /// de texte de référence pour suivre Dynamic Type.
    public static func inter(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        Font.custom(family, size: size, relativeTo: textStyle).weight(weight)
    }

    /// Grand titre d'écran (Inter 28 / 700).
    public static let largeTitle = inter(28, weight: .bold, relativeTo: .largeTitle)
    /// Titre de section (Inter 22 / 700).
    public static let title = inter(22, weight: .bold, relativeTo: .title)
    /// Sous-titre (Inter 18 / 600).
    public static let title2 = inter(18, weight: .semibold, relativeTo: .title2)
    /// En-tête (Inter 16 / 600).
    public static let headline = inter(16, weight: .semibold, relativeTo: .headline)
    /// Corps de texte (Inter 16 / 400).
    public static let body = inter(16, weight: .regular, relativeTo: .body)
    /// Corps accentué (Inter 16 / 500).
    public static let bodyMedium = inter(16, weight: .medium, relativeTo: .body)
    /// Texte secondaire (Inter 14 / 400).
    public static let callout = inter(14, weight: .regular, relativeTo: .callout)
    /// Légende (Inter 13 / 400).
    public static let caption = inter(13, weight: .regular, relativeTo: .caption)
    /// Légende accentuée (Inter 13 / 600) — pour badges/pastilles.
    public static let captionMedium = inter(13, weight: .semibold, relativeTo: .caption)
}

public extension View {
    /// Applique une police Inter du design system.
    func dsFont(_ font: Font) -> some View {
        self.font(font)
    }
}
