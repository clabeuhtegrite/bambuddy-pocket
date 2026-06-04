// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import SwiftUI

// MARK: - Carte

/// Conteneur « carte » de la DA Bambuddy : surface arrondie, bordure fine, ombre douce.
public struct DSCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsCardSurface()
    }
}

/// Applique l'habillage de carte (surface, rayon, bordure, ombre) à n'importe quelle vue.
public struct DSCardSurfaceModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(DSColor.card)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                    .strokeBorder(DSColor.border, lineWidth: DSBorder.thin)
            )
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

public extension View {
    /// Habille la vue en carte de la DA (surface, bordure, rayon, ombre).
    func dsCardSurface() -> some View {
        modifier(DSCardSurfaceModifier())
    }
}

// MARK: - Badge de statut

/// Pastille de statut (`rounded-full`) colorée selon une intention sémantique.
public struct DSStatusBadge: View {
    private let title: String
    private let intent: DSStatusIntent
    private let showsDot: Bool

    public init(_ title: String, intent: DSStatusIntent, showsDot: Bool = true) {
        self.title = title
        self.intent = intent
        self.showsDot = showsDot
    }

    public var body: some View {
        HStack(spacing: DSSpacing.xs) {
            if showsDot {
                Circle()
                    .fill(intent.color)
                    .frame(width: 7, height: 7)
            }
            Text(title)
                .font(DSFont.captionMedium)
        }
        .foregroundStyle(intent.color)
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(intent.color.opacity(0.14))
        .clipShape(Capsule())
    }
}

// MARK: - Boutons

/// Style de bouton principal (accent vert plein).
public struct DSPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.bodyMedium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.sm + 2)
            .padding(.horizontal, DSSpacing.md)
            .background(configuration.isPressed ? DSColor.accentDark : DSColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

/// Style de bouton secondaire (contour accent sur surface).
public struct DSSecondaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.bodyMedium)
            .foregroundStyle(DSColor.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.sm + 2)
            .padding(.horizontal, DSSpacing.md)
            .background(DSColor.accent.opacity(configuration.isPressed ? 0.18 : 0.10))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous)
                    .strokeBorder(DSColor.accent.opacity(0.5), lineWidth: DSBorder.thin)
            )
    }
}

/// Style de bouton destructif (rouge sémantique plein).
public struct DSDestructiveButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.bodyMedium)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.sm + 2)
            .padding(.horizontal, DSSpacing.md)
            .background(DSColor.statusError.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
    }
}

public extension ButtonStyle where Self == DSPrimaryButtonStyle {
    /// Bouton principal (accent vert plein).
    static var dsPrimary: DSPrimaryButtonStyle {
        DSPrimaryButtonStyle()
    }
}

public extension ButtonStyle where Self == DSSecondaryButtonStyle {
    /// Bouton secondaire (contour accent).
    static var dsSecondary: DSSecondaryButtonStyle {
        DSSecondaryButtonStyle()
    }
}

public extension ButtonStyle where Self == DSDestructiveButtonStyle {
    /// Bouton destructif (rouge sémantique).
    static var dsDestructive: DSDestructiveButtonStyle {
        DSDestructiveButtonStyle()
    }
}

// MARK: - Fond d'écran & séparateur

/// Fond d'écran standard de la DA (couleur de fond adaptative, ignore les marges sûres).
public struct DSScreenBackground: View {
    public init() {}

    public var body: some View {
        DSColor.background.ignoresSafeArea()
    }
}

/// Séparateur fin de la DA (bordure adaptative).
public struct DSSeparator: View {
    public init() {}

    public var body: some View {
        Rectangle()
            .fill(DSColor.border)
            .frame(height: DSBorder.thin)
    }
}
