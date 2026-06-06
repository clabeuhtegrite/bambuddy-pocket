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

    /// Durée lisible (« 2 min », « 1 h 5 min », « 45 s ») à partir de secondes. Délègue au formateur
    /// unique `DurationPresentation` (granularité seconde sous la minute).
    static func duration(seconds: Int) -> String {
        DurationPresentation.string(seconds: seconds, showsSeconds: true)
    }
}
