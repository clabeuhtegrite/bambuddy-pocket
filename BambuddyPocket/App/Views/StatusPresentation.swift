// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Libellés **localisés** des statuts bruts renvoyés par le serveur (archives, file, projets,
/// journal). Évite d'afficher la valeur brute anglaise (`completed`, `printing`…) en français,
/// espagnol ou allemand. Replie sur la valeur capitalisée si le statut est inconnu.
enum StatusPresentation {
    static func label(_ status: String) -> String {
        switch status.lowercased() {
        case "completed", "success", "finished", "done":
            String(localized: "status.completed", defaultValue: "Completed")
        case "failed", "error":
            String(localized: "status.failed", defaultValue: "Failed")
        case "stopped":
            String(localized: "status.stopped", defaultValue: "Stopped")
        case "cancelled", "canceled":
            String(localized: "status.cancelled", defaultValue: "Cancelled")
        case "skipped":
            String(localized: "status.skipped", defaultValue: "Skipped")
        case "printing", "running", "in_progress":
            String(localized: "status.printing", defaultValue: "Printing")
        case "waiting", "pending", "queued":
            String(localized: "status.waiting", defaultValue: "Waiting")
        case "scheduled":
            String(localized: "status.scheduled", defaultValue: "Scheduled")
        case "paused":
            String(localized: "status.paused", defaultValue: "Paused")
        case "active", "idle", "ready":
            String(localized: "status.ready", defaultValue: "Ready")
        default:
            status.capitalized
        }
    }
}
