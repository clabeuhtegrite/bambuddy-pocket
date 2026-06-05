// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Formatage et libellés (localisés) pour l'affichage de l'état d'une imprimante.
enum PrinterPresentation {
    /// Libellé localisé de l'état de haut niveau.
    static func stateText(_ state: PrinterState?) -> String {
        switch state {
        case .none:
            String(localized: "Unknown")
        case .idle:
            String(localized: "Idle")
        case .prepare:
            String(localized: "Preparing")
        case .running:
            String(localized: "Printing")
        case .pause:
            String(localized: "Paused")
        case .finish:
            String(localized: "Finished")
        case .failed:
            String(localized: "Failed")
        case .slicing:
            String(localized: "Slicing")
        case let .unknown(value):
            value
        }
    }

    /// Couleur sémantique associée à l'état (badge, pastille).
    static func stateColor(_ state: PrinterState?) -> Color {
        DSStatusIntent.forPrinterState(state).color
    }

    /// Libellé parlant de l'extrudeur actif (modèles double buse), à partir de l'index brut
    /// rapporté par le firmware (`active_extruder`, 0-indexé : 0 = gauche, 1 = droite).
    ///
    /// On évite le chiffre brut « 2 » (peu parlant) au profit de « Buse 2 (droite) » / « Buse 1
    /// (gauche) », cohérent avec les lignes de température « Buse 1 / Buse 2 ». Au-delà de la
    /// seconde buse (cas non attendu sur le matériel actuel) on retombe sur « Buse N ».
    static func activeExtruderLabel(_ index: Int) -> String {
        let nozzleNumber = index + 1
        switch index {
        case 0:
            return String(localized: "Nozzle \(nozzleNumber) (left)")
        case 1:
            return String(localized: "Nozzle \(nozzleNumber) (right)")
        default:
            return String(localized: "Nozzle \(nozzleNumber)")
        }
    }

    /// Température en °C arrondie (« 210° »), ou « — » si inconnue.
    static func temperature(_ value: Double?) -> String {
        guard let value else {
            return "—"
        }
        return "\(Int(value.rounded()))°"
    }

    /// Couple courant/cible (« 210° / 220° »).
    static func temperaturePair(_ current: Double?, _ target: Double?) -> String {
        guard let target, target > 0 else {
            return temperature(current)
        }
        return "\(temperature(current)) / \(temperature(target))"
    }

    /// Temps restant formaté (« 1 h 20 min » / « 12 min »), ou `nil` si non pertinent.
    static func remainingTime(minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else {
            return nil
        }
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return String(localized: "\(hours) h \(mins) min")
        }
        return String(localized: "\(mins) min")
    }

    /// Force du signal Wi-Fi (dBm) avec une qualité lisible (« -47 dBm · Bon »).
    ///
    /// Seuils usuels : ≥ -50 excellent, ≥ -60 bon, ≥ -70 moyen, sinon faible.
    static func wifiSignal(_ dBm: Int) -> String {
        let quality = switch dBm {
        case (-50)...:
            String(localized: "Excellent")
        case (-60)...:
            String(localized: "Good")
        case (-70)...:
            String(localized: "Fair")
        default:
            String(localized: "Weak")
        }
        return "\(dBm) dBm · \(quality)"
    }

    /// Libellé localisé de la sévérité d'une erreur HMS.
    static func severityText(_ severity: HMSSeverity) -> String {
        switch severity {
        case .fatal:
            String(localized: "Fatal")
        case .serious:
            String(localized: "Serious")
        case .common:
            String(localized: "Warning")
        case .info:
            String(localized: "Info")
        }
    }

    /// Couleur associée à la sévérité d'une erreur HMS.
    static func severityColor(_ severity: HMSSeverity) -> Color {
        DSStatusIntent.forHMSSeverity(severity).color
    }

    /// Titre humain d'une erreur HMS : raison connue traduite (Layer shift, Filament runout…) ou,
    /// à défaut, un libellé générique « Printer error » plutôt que le code brut.
    static func hmsTitle(_ error: HMSError) -> String {
        switch error.failureReasonKey {
        case "hms.reason.layerShift":
            String(localized: "Layer shift")
        case "hms.reason.filamentRunout":
            String(localized: "Filament runout")
        case "hms.reason.cloggedNozzle":
            String(localized: "Clogged nozzle")
        case "hms.reason.bedNotHeating":
            String(localized: "Heated bed not heating")
        case "hms.reason.nozzleNotHeating":
            String(localized: "Nozzle not heating")
        case "hms.reason.firstLayerFailed":
            String(localized: "First layer issue")
        case "hms.reason.spaghettiDetected":
            String(localized: "Spaghetti detected")
        default:
            String(localized: "Printer error")
        }
    }

    /// Convertit une couleur de bobine au format hex `RRGGBB` ou `RRGGBBAA` en `Color`.
    static func color(hexRGBA hex: String?) -> Color? {
        guard var string = hex else {
            return nil
        }
        if string.hasPrefix("#") {
            string.removeFirst()
        }
        guard string.count == 6 || string.count == 8, let value = UInt64(string, radix: 16) else {
            return nil
        }
        let red, green, blue, alpha: Double
        if string.count == 8 {
            red = Double((value >> 24) & 0xFF) / 255
            green = Double((value >> 16) & 0xFF) / 255
            blue = Double((value >> 8) & 0xFF) / 255
            alpha = Double(value & 0xFF) / 255
        } else {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
            alpha = 1
        }
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
