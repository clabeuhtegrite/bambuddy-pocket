// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Catégorie d'un événement temps réel digne d'une notification en-app.
public enum NotableEventKind: Sendable, Hashable {
    case printStarted
    case printCompleted
    case missingSpool
    case plateNotEmpty
    case hmsError
    case archiveCreated
}

/// Notification en-app dérivée d'un événement temps réel : sa catégorie, l'imprimante concernée
/// (le cas échéant) et un éventuel détail affichable (nom du travail, code HMS, message…).
public struct NotableEvent: Sendable, Hashable {
    public let kind: NotableEventKind
    /// Identifiant de l'imprimante concernée, ou `nil` (ex. création d'archive).
    public let printerID: Int?
    /// Détail facultatif (nom du travail, libellé d'archive, code HMS le plus grave…).
    public let detail: String?

    public init(kind: NotableEventKind, printerID: Int?, detail: String? = nil) {
        self.kind = kind
        self.printerID = printerID
        self.detail = detail
    }
}

public extension WebSocketEvent {
    /// Traduit l'événement en notification en-app, ou `nil` si l'événement n'est pas pertinent
    /// pour l'utilisateur.
    ///
    /// Note : les erreurs HMS graves ne sont **pas** un type d'événement WebSocket distinct ;
    /// elles arrivent via `printer_status.hms_errors`. Leur dérivation se fait par transition
    /// d'état (cf. `PrinterStatus.severeHMSEvent(comparedTo:printerID:)`).
    var notableEvent: NotableEvent? {
        switch self {
        case let .printStart(printerID, status):
            NotableEvent(kind: .printStarted, printerID: printerID, detail: status?.jobName)
        case let .printComplete(printerID, status):
            NotableEvent(kind: .printCompleted, printerID: printerID, detail: status?.jobName)
        case let .missingSpoolAssignment(printerID, name):
            NotableEvent(kind: .missingSpool, printerID: printerID, detail: name)
        case let .plateNotEmpty(printerID, name, message):
            printerID.map {
                NotableEvent(kind: .plateNotEmpty, printerID: $0, detail: message ?? name)
            }
        case let .archiveCreated(name):
            NotableEvent(kind: .archiveCreated, printerID: nil, detail: name)
        case .printerStatus, .backgroundDispatch, .pong, .other:
            nil
        }
    }
}

public extension PrinterStatus {
    /// Nom du travail en cours, le plus parlant disponible.
    var jobName: String? {
        [subtaskName, currentPrint, gcodeFile]
            .compactMap(\.self)
            .first { !$0.isEmpty }
    }

    /// Erreur HMS grave (fatale ou sérieuse) apparue dans ce statut mais absente du précédent —
    /// pour ne notifier qu'à la **transition** (et pas à chaque rafraîchissement).
    ///
    /// - Parameters:
    ///   - previous: statut précédemment connu (ou `nil` au premier reçu).
    ///   - printerID: identifiant de l'imprimante, reporté dans la notification.
    /// - Returns: une notification HMS, ou `nil` si aucune nouvelle erreur grave.
    func severeHMSEvent(comparedTo previous: PrinterStatus?, printerID: Int) -> NotableEvent? {
        let severeNow = Set(Self.severeCodes(in: self))
        guard !severeNow.isEmpty else { return nil }
        let severeBefore = Set(Self.severeCodes(in: previous))
        let appeared = severeNow.subtracting(severeBefore)
        guard let code = appeared.min() else { return nil }
        return NotableEvent(kind: .hmsError, printerID: printerID, detail: code)
    }

    private static func severeCodes(in status: PrinterStatus?) -> [String] {
        (status?.hmsErrors ?? [])
            .filter { error in
                switch error.severityLevel {
                case .fatal, .serious: true
                case .common, .info: false
                }
            }
            .map(\.code)
    }
}
