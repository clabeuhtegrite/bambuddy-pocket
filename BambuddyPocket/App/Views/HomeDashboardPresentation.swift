// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Imprimante + son statut temps réel fusionné, agrégés pour l'accueil.
struct PrinterSnapshot: Identifiable, Hashable {
    let printer: Printer
    let status: PrinterStatus?

    var id: Int {
        printer.id
    }

    var isPrinting: Bool {
        status?.isPrinting ?? false
    }

    /// Progression (0…1) si une impression est active.
    var progressFraction: Double? {
        guard isPrinting else { return nil }
        return status?.progressFraction
    }
}

/// Niveau de gravité d'un bandeau d'alerte d'accueil (ordre = priorité décroissante).
enum HomeAlertSeverity: Int {
    case error = 0
    case warning = 1
}

/// Bandeau d'alerte conditionnel de l'accueil : n'apparaît **que** si une condition réellement
/// alarmante est détectée (erreur HMS de gravité ≥ serious, bobine AMS presque vide, plateau non
/// vidé). Réplique la logique de gravité corrigée (#81) : **pas de fausse alarme** sur les codes
/// informatifs/de statut émis en continu.
struct HomeAlert: Identifiable, Hashable {
    let id: String
    let severity: HomeAlertSeverity
    let title: String
    let detail: String
}

/// Calculs purs (testables sans UI) pour l'agrégation de l'accueil.
enum HomeDashboardPresentation {
    /// Construit les instantanés triés : imprimantes en cours d'impression d'abord (les plus
    /// avancées en tête), puis les autres par nom.
    static func snapshots(printers: [Printer], status: (Printer) -> PrinterStatus?) -> [PrinterSnapshot] {
        let snapshots = printers.map { PrinterSnapshot(printer: $0, status: status($0)) }
        return snapshots.sorted { lhs, rhs in
            if lhs.isPrinting != rhs.isPrinting {
                return lhs.isPrinting && !rhs.isPrinting
            }
            if lhs.isPrinting, rhs.isPrinting {
                return (lhs.progressFraction ?? 0) > (rhs.progressFraction ?? 0)
            }
            return lhs.printer.name.localizedCaseInsensitiveCompare(rhs.printer.name) == .orderedAscending
        }
    }

    /// Imprimante mise en avant dans la carte hero : la première en impression (la plus avancée),
    /// si une impression est active.
    static func heroSnapshot(_ snapshots: [PrinterSnapshot]) -> PrinterSnapshot? {
        snapshots.first { $0.isPrinting }
    }

    /// Nombre d'imprimantes en cours d'impression.
    static func printingCount(_ snapshots: [PrinterSnapshot]) -> Int {
        snapshots.count(where: \.isPrinting)
    }

    /// Bandeau d'alerte le plus prioritaire parmi toutes les imprimantes (ou `nil` si rien
    /// d'alarmant). Priorité : erreur HMS > plateau non vidé > bobine AMS presque vide.
    static func alert(_ snapshots: [PrinterSnapshot], lowFilamentThreshold: Int = 10) -> HomeAlert? {
        var alerts: [HomeAlert] = []
        for snapshot in snapshots {
            guard let status = snapshot.status else { continue }
            let name = snapshot.printer.name

            // 1) Erreur HMS alarmante (gravité effective ≥ serious — cf. #81).
            if let error = status.mostSevereError {
                alerts.append(HomeAlert(
                    id: "hms-\(snapshot.id)",
                    severity: .error,
                    title: PrinterPresentation.hmsTitle(error),
                    detail: String(localized: "\(error.displayCode) on \(name)")
                ))
            }

            // 2) Plateau non vidé (impression terminée, attente de retrait).
            if status.awaitingPlateClear == true {
                alerts.append(HomeAlert(
                    id: "plate-\(snapshot.id)",
                    severity: .warning,
                    title: String(localized: "Plate not cleared"),
                    detail: String(localized: "Remove the print from \(name) to continue")
                ))
            }

            // 3) Bobine AMS presque vide (un slot avec un filament chargé sous le seuil).
            if let low = lowestFilament(in: status), low.remain <= lowFilamentThreshold {
                alerts.append(HomeAlert(
                    id: "ams-\(snapshot.id)-\(low.slot)",
                    severity: .warning,
                    title: String(localized: "AMS · spool almost empty"),
                    detail: String(localized: "Slot \(low.slot) — about \(low.remain)% left on \(name)")
                ))
            }
        }
        return alerts.min { $0.severity.rawValue < $1.severity.rawValue }
    }

    /// Slot AMS chargé avec le niveau restant le plus bas (numéro de slot 1-based, niveau %),
    /// ou `nil` si aucun slot ne rapporte de niveau. Ignore les slots vides (pas de filament).
    private static func lowestFilament(in status: PrinterStatus) -> (slot: Int, remain: Int)? {
        var lowest: (slot: Int, remain: Int)?
        for unit in status.ams ?? [] {
            for tray in unit.tray ?? [] {
                guard let remain = tray.remain,
                      let type = tray.trayType, !type.isEmpty
                else { continue }
                let slot = unit.id * 4 + tray.id + 1
                if let current = lowest {
                    if remain < current.remain {
                        lowest = (slot, remain)
                    }
                } else {
                    lowest = (slot, remain)
                }
            }
        }
        return lowest
    }
}
