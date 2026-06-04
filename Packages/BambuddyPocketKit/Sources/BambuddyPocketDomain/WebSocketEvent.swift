// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Événement temps réel reçu sur le WebSocket (`ws(s)://host/api/v1/ws`).
///
/// Enveloppe `{ "type": <str>, "printer_id"?: <int>, "data"?: <obj> }` (cf.
/// `docs/bambuddy-api.md` §4). Seuls les types utiles aux notifications/au temps réel sont
/// modélisés ; les autres retombent sur `.other` (forward-compatibilité).
public enum WebSocketEvent: Sendable, Hashable {
    /// Mise à jour (souvent partielle) de l'état d'une imprimante — à **fusionner**.
    case printerStatus(printerID: Int, status: PrinterStatus)
    /// Début d'impression.
    case printStart(printerID: Int, status: PrinterStatus?)
    /// Fin d'impression.
    case printComplete(printerID: Int, status: PrinterStatus?)
    /// Bobine(s) manquante(s) au lancement (`missing_slots`).
    case missingSpoolAssignment(printerID: Int, printerName: String?)
    /// Plateau non vide détecté avant l'impression suivante (`message` décrit la détection).
    case plateNotEmpty(printerID: Int?, printerName: String?, message: String?)
    /// Nouvelle archive d'impression créée (`name` = libellé affichable si présent).
    case archiveCreated(name: String?)
    /// État de la distribution automatique en arrière-plan (`background_dispatch`).
    case backgroundDispatch(state: BackgroundDispatchState)
    /// Réponse keepalive.
    case pong
    /// Tout autre type non pris en charge explicitement (conserve le libellé brut).
    case other(type: String)

    /// Identifiant d'imprimante porté par l'événement, s'il y en a un.
    public var printerID: Int? {
        switch self {
        case let .printerStatus(printerID, _): printerID
        case let .printStart(printerID, _): printerID
        case let .printComplete(printerID, _): printerID
        case let .missingSpoolAssignment(printerID, _): printerID
        case let .plateNotEmpty(printerID, _, _): printerID
        case .archiveCreated, .backgroundDispatch, .pong, .other: nil
        }
    }
}

extension WebSocketEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case printerId
        case printerName
        case message
        case data
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let printerID = try container.decodeIfPresent(Int.self, forKey: .printerId)

        switch type {
        case "printer_status":
            let status = try container.decode(PrinterStatus.self, forKey: .data)
            self = .printerStatus(printerID: printerID ?? 0, status: status)
        case "print_start":
            let status = try container.decodeIfPresent(PrinterStatus.self, forKey: .data)
            self = .printStart(printerID: printerID ?? 0, status: status)
        case "print_complete":
            let status = try container.decodeIfPresent(PrinterStatus.self, forKey: .data)
            self = .printComplete(printerID: printerID ?? 0, status: status)
        case "missing_spool_assignment":
            let name = try container.decodeIfPresent(String.self, forKey: .printerName)
            self = .missingSpoolAssignment(printerID: printerID ?? 0, printerName: name)
        case "plate_not_empty":
            let name = try container.decodeIfPresent(String.self, forKey: .printerName)
            let message = try container.decodeIfPresent(String.self, forKey: .message)
            self = .plateNotEmpty(printerID: printerID, printerName: name, message: message)
        case "archive_created":
            let archive = try container.decodeIfPresent(ArchiveSummary.self, forKey: .data)
            self = .archiveCreated(name: archive?.displayName)
        case "background_dispatch":
            let state = try container.decode(BackgroundDispatchState.self, forKey: .data)
            self = .backgroundDispatch(state: state)
        case "pong":
            self = .pong
        default:
            self = .other(type: type)
        }
    }
}

/// Sous-ensemble minimal d'une archive transportée par `archive_created` — on n'extrait qu'un
/// libellé affichable (le reste de l'objet est ignoré).
private struct ArchiveSummary: Decodable {
    let name: String?
    let subtaskName: String?
    let fileName: String?

    var displayName: String? {
        [name, subtaskName, fileName]
            .compactMap(\.self)
            .first { !$0.isEmpty }
    }
}
