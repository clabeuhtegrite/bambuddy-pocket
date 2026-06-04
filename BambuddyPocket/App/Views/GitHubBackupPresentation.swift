// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Formatage pour l'affichage de la sauvegarde distante Git.
enum GitHubBackupPresentation {
    /// Libellé localisé d'un statut de sauvegarde (success/failed/skipped/running).
    static func statusLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "success", "completed": String(localized: "Success")
        case "failed", "error": String(localized: "Failed")
        case "skipped": String(localized: "Skipped")
        case "running", "in_progress": String(localized: "Running")
        default: status.capitalized
        }
    }

    /// Libellé localisé d'un déclencheur (manual/scheduled).
    static func triggerLabel(_ trigger: String) -> String {
        switch trigger.lowercased() {
        case "manual": String(localized: "Manual")
        case "scheduled": String(localized: "Scheduled")
        default: trigger.capitalized
        }
    }

    /// Date ISO formatée localement, tolérante à l'ISO-8601 sans fuseau émis par le serveur.
    static func date(_ iso: String?) -> String? {
        PrintLogPresentation.date(iso)
    }
}
