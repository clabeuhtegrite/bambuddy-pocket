// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import Foundation

/// Formatage pour l'affichage du support / journal applicatif.
enum SupportPresentation {
    /// Intention sémantique (couleur) d'un niveau de journal.
    static func levelIntent(_ level: String?) -> DSStatusIntent {
        switch (level ?? "").uppercased() {
        case "ERROR", "CRITICAL", "FATAL": .error
        case "WARNING", "WARN": .warning
        case "INFO": .success
        default: .neutral
        }
    }

    /// Durée lisible (« 2 min », « 1 h 5 min ») à partir de secondes.
    static func duration(seconds: Int) -> String {
        let totalMinutes = max(seconds, 0) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return String(localized: "\(hours) h \(minutes) min")
        }
        if minutes > 0 {
            return String(localized: "\(minutes) min")
        }
        return String(localized: "\(seconds) s")
    }
}
