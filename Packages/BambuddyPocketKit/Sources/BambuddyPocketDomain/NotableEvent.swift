// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Catégorie d'un événement temps réel digne d'une notification en-app.
public enum NotableEventKind: Sendable, Hashable {
    case printStarted
    case printCompleted
    case missingSpool
    case plateNotEmpty
}

public extension WebSocketEvent {
    /// Traduit l'événement en notification en-app (catégorie + imprimante concernée), ou `nil`
    /// si l'événement n'est pas pertinent pour l'utilisateur.
    var notableEvent: (kind: NotableEventKind, printerID: Int)? {
        switch self {
        case let .printStart(printerID, _):
            (kind: .printStarted, printerID: printerID)
        case let .printComplete(printerID, _):
            (kind: .printCompleted, printerID: printerID)
        case let .missingSpoolAssignment(printerID, _):
            (kind: .missingSpool, printerID: printerID)
        case let .plateNotEmpty(printerID):
            printerID.map { (kind: NotableEventKind.plateNotEmpty, printerID: $0) }
        case .printerStatus, .pong, .other:
            nil
        }
    }
}
