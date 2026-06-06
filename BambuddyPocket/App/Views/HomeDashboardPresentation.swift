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

    /// Nom du travail en cours (sous-tâche, sinon impression courante), `nil` si au repos.
    var jobName: String? {
        guard isPrinting else { return nil }
        return status?.subtaskName ?? status?.currentPrint
    }

    /// Nombre de bobines AMS **chargées** (slots avec un type de filament), `nil` si aucun AMS.
    var loadedSpoolCount: Int? {
        guard let units = status?.ams, !units.isEmpty else { return nil }
        return units.reduce(0) { sum, unit in
            sum + (unit.tray ?? []).count { ($0.trayType?.isEmpty == false) }
        }
    }

    /// Résumé d'alerte de la carte (le plus prioritaire) : erreur HMS > plateau > bobine basse.
    /// `nil` si rien d'alarmant — la carte montre alors l'état AMS neutre.
    func cardAlert(lowFilamentThreshold: Int = 10) -> HomeAlertKind? {
        guard let status else { return nil }
        if status.mostSevereError != nil { return .hmsError }
        if status.awaitingPlateClear == true { return .plateNotCleared }
        let low = HomeDashboardPresentation.lowestLoadedFilament(in: status)
        if let low, low <= lowFilamentThreshold { return .lowFilament }
        return nil
    }
}

/// Niveau de gravité d'un bandeau d'alerte d'accueil (ordre = priorité décroissante).
enum HomeAlertSeverity: Int {
    case error = 0
    case warning = 1
}

/// Nature d'un bandeau d'alerte d'accueil — détermine l'action directe proposée sur la bannière.
enum HomeAlertKind: Hashable {
    /// Erreur HMS alarmante (ouvre le détail).
    case hmsError
    /// Plateau non vidé : propose l'action directe « Nettoyé » (clear-plate) sur la bannière (#2).
    case plateNotCleared
    /// Bobine AMS presque vide (ouvre le détail).
    case lowFilament
}

/// Bandeau d'alerte conditionnel de l'accueil : n'apparaît **que** si une condition réellement
/// alarmante est détectée (erreur HMS de gravité ≥ serious, bobine AMS presque vide, plateau non
/// vidé). Réplique la logique de gravité corrigée (#81) : **pas de fausse alarme** sur les codes
/// informatifs/de statut émis en continu.
struct HomeAlert: Identifiable, Hashable {
    let id: String
    let severity: HomeAlertSeverity
    let kind: HomeAlertKind
    /// Imprimante concernée (pour ouvrir son détail ou agir directement, p. ex. clear-plate).
    let printerID: Int
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

    /// Puissance instantanée (W) par imprimante, dérivée des prises connectées **liées** à une
    /// imprimante et **joignables**, dont la mesure de puissance est disponible (retour device A7).
    /// Une imprimante absente de la map n'a pas de prise/mesure → la carte n'affiche pas de watts.
    /// Si plusieurs prises sont liées à la même imprimante, leurs puissances sont **additionnées**.
    static func powerByPrinter(
        plugs: [SmartPlug],
        statuses: [Int: SmartPlugStatus]
    ) -> [Int: Double] {
        var result: [Int: Double] = [:]
        for plug in plugs {
            guard let printerID = plug.printerID else { continue }
            guard let status = statuses[plug.id], status.isReachable else { continue }
            guard let power = status.energy?.power else { continue }
            result[printerID, default: 0] += power
        }
        return result
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

    /// Nombre d'imprimantes **prêtes** : connectées, au repos (ni en impression, ni en erreur).
    static func readyCount(_ snapshots: [PrinterSnapshot]) -> Int {
        snapshots.count { snapshot in
            guard let status = snapshot.status, status.connected != false else { return false }
            if snapshot.isPrinting { return false }
            if status.mostSevereError != nil { return false }
            return true
        }
    }

    /// Nombre d'imprimantes présentant une **alerte** (erreur HMS, plateau non vidé, bobine basse).
    static func alertCount(_ snapshots: [PrinterSnapshot], lowFilamentThreshold: Int = 10) -> Int {
        snapshots.count { snapshot in
            guard let status = snapshot.status else { return false }
            if status.mostSevereError != nil { return true }
            if status.awaitingPlateClear == true { return true }
            if let low = lowestFilament(in: status), low.remain <= lowFilamentThreshold { return true }
            return false
        }
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
                    kind: .hmsError,
                    printerID: snapshot.id,
                    title: PrinterPresentation.hmsTitle(error),
                    detail: String(localized: "\(error.displayCode) on \(name)")
                ))
            }

            // 2) Plateau non vidé (impression terminée, attente de retrait).
            if status.awaitingPlateClear == true {
                alerts.append(HomeAlert(
                    id: "plate-\(snapshot.id)",
                    severity: .warning,
                    kind: .plateNotCleared,
                    printerID: snapshot.id,
                    title: String(localized: "Plate not cleared"),
                    detail: String(localized: "Remove the print from \(name) to continue")
                ))
            }

            // 3) Bobine AMS presque vide (un slot avec un filament chargé sous le seuil).
            if let low = lowestFilament(in: status), low.remain <= lowFilamentThreshold {
                alerts.append(HomeAlert(
                    id: "ams-\(snapshot.id)-\(low.slot)",
                    severity: .warning,
                    kind: .lowFilament,
                    printerID: snapshot.id,
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

    /// Niveau restant le plus bas parmi les slots **chargés** (filament présent), `nil` si aucun.
    /// Variante légère de `lowestFilament` pour le résumé d'une carte (sans numéro de slot).
    static func lowestLoadedFilament(in status: PrinterStatus) -> Int? {
        lowestFilament(in: status)?.remain
    }
}
