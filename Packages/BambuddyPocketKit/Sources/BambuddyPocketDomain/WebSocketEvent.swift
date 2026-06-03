// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Événement temps réel reçu sur le WebSocket (`ws(s)://host/api/v1/ws`).
///
/// Enveloppe `{ "type": <str>, "printer_id"?: <int>, "data"?: <obj> }` (cf.
/// `docs/bambuddy-api.md` §4). Seuls les types utiles au MVP sont modélisés ; les autres
/// retombent sur `.other` (forward-compatibilité).
public enum WebSocketEvent: Sendable, Hashable {
    /// Mise à jour (souvent partielle) de l'état d'une imprimante — à **fusionner**.
    case printerStatus(printerID: Int, status: PrinterStatus)
    /// Début d'impression.
    case printStart(printerID: Int, status: PrinterStatus?)
    /// Fin d'impression.
    case printComplete(printerID: Int, status: PrinterStatus?)
    /// Bobine(s) manquante(s) au lancement (`missing_slots`).
    case missingSpoolAssignment(printerID: Int, printerName: String?)
    /// Plateau non vide détecté avant l'impression suivante.
    case plateNotEmpty(printerID: Int?)
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
        case let .plateNotEmpty(printerID): printerID
        case .pong, .other: nil
        }
    }
}

extension WebSocketEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case type
        case printerId
        case printerName
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
            self = .plateNotEmpty(printerID: printerID)
        case "pong":
            self = .pong
        default:
            self = .other(type: type)
        }
    }
}
