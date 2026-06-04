// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Formatage pour l'affichage de l'intégration Spoolman.
enum SpoolmanPresentation {
    /// Libellé localisé d'un mode de synchronisation (auto/manual).
    static func syncModeLabel(_ mode: String) -> String {
        switch mode.lowercased() {
        case "auto": String(localized: "Automatic")
        case "manual": String(localized: "Manual")
        default: mode.capitalized
        }
    }
}
