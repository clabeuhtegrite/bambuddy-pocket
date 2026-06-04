// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import Foundation

/// Formatage pour l'affichage des imprimantes virtuelles.
enum VirtualPrinterPresentation {
    /// Libellé d'état (en cours / activé / désactivé).
    static func stateLabel(_ printer: VirtualPrinter) -> String {
        if printer.isRunning {
            String(localized: "Running")
        } else if printer.enabled {
            String(localized: "Enabled")
        } else {
            String(localized: "Disabled")
        }
    }

    /// Intention sémantique (couleur) de l'état.
    static func stateIntent(_ printer: VirtualPrinter) -> DSStatusIntent {
        if printer.isRunning {
            .success
        } else if printer.enabled {
            .accent
        } else {
            .neutral
        }
    }

    /// Libellé localisé d'un mode de dispatch.
    static func modeLabel(_ mode: String) -> String {
        switch mode.lowercased() {
        case "immediate": String(localized: "Immediate")
        case "review": String(localized: "Review")
        case "print_queue": String(localized: "Print queue")
        case "proxy": String(localized: "Proxy")
        default: mode.capitalized
        }
    }
}
