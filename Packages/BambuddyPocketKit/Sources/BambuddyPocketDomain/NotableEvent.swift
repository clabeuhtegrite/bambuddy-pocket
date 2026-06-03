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
            (.printStarted, printerID)
        case let .printComplete(printerID, _):
            (.printCompleted, printerID)
        case let .missingSpoolAssignment(printerID, _):
            (.missingSpool, printerID)
        case let .plateNotEmpty(printerID):
            printerID.map { (.plateNotEmpty, $0) }
        case .printerStatus, .pong, .other:
            nil
        }
    }
}
