// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Bandeau d'alerte d'accueil (ambre/rouge selon la gravité), tapotable pour ouvrir le détail.
///
/// Pour une alerte **« plateau non vidé »**, le bandeau propose une **action directe** « Nettoyé »
/// (clear-plate) en ligne (#2) : plus besoin d'aller dans Imprimantes > X > défiler. Une légère
/// confirmation est demandée avant l'envoi.
struct HomeAlertBanner: View {
    let alert: HomeAlert
    let onTap: () -> Void
    /// Action de retrait de plateau (présente seulement pour `.plateNotCleared`), `nil` sinon.
    var onClearPlate: (() -> Void)?

    @State private var confirmingClear = false

    init(alert: HomeAlert, onClearPlate: (() -> Void)? = nil, onTap: @escaping () -> Void) {
        self.alert = alert
        self.onClearPlate = onClearPlate
        self.onTap = onTap
    }

    private var tint: Color {
        switch alert.severity {
        case .error: DSColor.statusError
        case .warning: DSColor.statusWarning
        }
    }

    /// L'action directe est proposée seulement pour le plateau non vidé et si un handler est fourni.
    private var showsClearAction: Bool {
        alert.kind == .plateNotCleared && onClearPlate != nil
    }

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Button(action: onTap) {
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(alert.title)
                            .font(DSFont.captionMedium)
                            .foregroundStyle(tint)
                        Text(alert.detail)
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: DSSpacing.sm)
                    if !showsClearAction {
                        Image(systemName: "chevron.right")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textMuted)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("Opens printer details"))

            if showsClearAction {
                Button {
                    confirmingClear = true
                } label: {
                    Text("Cleared")
                        .font(DSFont.captionMedium)
                        .padding(.horizontal, DSSpacing.sm)
                        .padding(.vertical, DSSpacing.xs)
                }
                .buttonStyle(.dsPrimary)
                .accessibilityHint(Text("Confirms the plate has been removed"))
            }
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: DSBorder.thin)
        )
        .confirmationDialog(
            "Mark plate as cleared?",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button("Cleared") { onClearPlate?() }
        } message: {
            Text("Confirm the print has been removed from the plate.")
        }
    }
}
