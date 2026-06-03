// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import SwiftUI

/// Formatage et couleurs pour l'affichage des archives d'impression.
enum ArchivePresentation {
    /// Couleur sémantique d'un statut d'archive (valeur brute serveur).
    static func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "success", "completed", "finished", "done":
            .green
        case "failed", "error":
            .red
        case "cancelled", "canceled", "stopped":
            .orange
        default:
            .secondary
        }
    }

    /// Durée formatée (« 1 h 20 min » / « 12 min ») à partir de secondes.
    static func duration(seconds: Int?) -> String? {
        guard let seconds, seconds > 0 else {
            return nil
        }
        let totalMinutes = seconds / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return String(localized: "\(hours) h \(minutes) min")
        }
        return String(localized: "\(minutes) min")
    }

    /// Masse de filament formatée (« 13 g »).
    static func filament(grams: Double?) -> String? {
        guard let grams, grams > 0 else {
            return nil
        }
        return String(localized: "\(Int(grams.rounded())) g")
    }

    /// Date ISO formatée localement ; repli sur la chaîne brute si le parsing échoue.
    static func date(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else {
            return nil
        }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let parsed = withFraction.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let parsed else {
            return iso
        }
        return parsed.formatted(date: .abbreviated, time: .shortened)
    }
}
