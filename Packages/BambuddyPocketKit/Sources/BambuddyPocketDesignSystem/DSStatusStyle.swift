// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import SwiftUI

/// Intention sémantique d'un statut, indépendante de l'écran.
///
/// Centralise le mapping état → couleur de la DA Bambuddy pour que tous les badges,
/// pastilles et barres de progression restent cohérents. Pur (testable sans UI).
public enum DSStatusIntent: Sendable, Hashable, CaseIterable {
    /// Vert d'accent — état actif/positif lié à l'impression (en cours).
    case accent
    /// Vert de statut — succès/terminé/en ligne.
    case success
    /// Ambre — avertissement/en pause.
    case warning
    /// Rouge — erreur/échec/hors ligne.
    case error
    /// Neutre — inactif/inconnu.
    case neutral

    /// Couleur de la DA associée à l'intention.
    public var color: Color {
        switch self {
        case .accent: DSColor.accent
        case .success: DSColor.statusOK
        case .warning: DSColor.statusWarning
        case .error: DSColor.statusError
        case .neutral: DSColor.textMuted
        }
    }
}

public extension DSStatusIntent {
    /// Mappe l'état de haut niveau d'une imprimante vers une intention sémantique.
    static func forPrinterState(_ state: PrinterState?) -> DSStatusIntent {
        switch state {
        case .running, .prepare: .accent
        case .finish: .success
        case .pause, .slicing: .warning
        case .failed: .error
        case .idle, .none: .neutral
        case .unknown: .neutral
        }
    }

    /// Mappe la sévérité d'une erreur HMS vers une intention sémantique.
    static func forHMSSeverity(_ severity: HMSSeverity) -> DSStatusIntent {
        switch severity {
        case .fatal, .serious: .error
        case .common: .warning
        case .info: .accent
        case .unknown: .neutral
        }
    }

    /// Mappe un drapeau succès/échec (journaux d'activité, archives) vers une intention.
    static func forSuccess(_ success: Bool) -> DSStatusIntent {
        success ? .success : .error
    }

    /// Mappe un statut brut renvoyé par le serveur (archives, file, lots) vers une intention.
    /// Insensible à la casse ; valeur inconnue → neutre.
    static func forRawStatus(_ status: String) -> DSStatusIntent {
        switch status.lowercased() {
        case "success", "completed", "finished", "done":
            .success
        case "printing", "active", "running":
            .accent
        case "failed", "error":
            .error
        case "cancelled", "canceled", "stopped":
            .warning
        case "pending", "queued", "scheduled":
            .neutral
        default:
            .neutral
        }
    }
}
