// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Formatage pour l'affichage du journal d'impression.
enum PrintLogPresentation {
    /// Libellé localisé d'un statut brut serveur (completed/failed/stopped/cancelled/skipped).
    static func statusLabel(_ status: String) -> String {
        switch status.lowercased() {
        case "completed", "success", "finished":
            String(localized: "print-log.status.completed", defaultValue: "Completed")
        case "failed", "error":
            String(localized: "print-log.status.failed", defaultValue: "Failed")
        case "stopped":
            String(localized: "print-log.status.stopped", defaultValue: "Stopped")
        case "cancelled", "canceled":
            String(localized: "print-log.status.cancelled", defaultValue: "Cancelled")
        case "skipped":
            String(localized: "print-log.status.skipped", defaultValue: "Skipped")
        default:
            status.capitalized
        }
    }

    /// Date ISO formatée localement. Le serveur émet de l'ISO-8601 **sans fuseau** pour le journal
    /// (p. ex. `2026-06-04T11:37:08`) : on tente d'abord les variantes avec fuseau, puis on replie
    /// sur un format local sans fuseau, et enfin sur la chaîne brute.
    static func date(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else {
            return nil
        }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = withFraction.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) {
            return parsed.formatted(date: .abbreviated, time: .shortened)
        }
        // Replie sur l'ISO sans fuseau : on ignore une éventuelle fraction de seconde.
        let trimmed = String(iso.prefix(19))
        if let parsed = naiveFormatter.date(from: trimmed) {
            return parsed.formatted(date: .abbreviated, time: .shortened)
        }
        return iso
    }

    /// Formateur tolérant pour l'ISO-8601 sans fuseau (`yyyy-MM-dd'T'HH:mm:ss`).
    private static let naiveFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
