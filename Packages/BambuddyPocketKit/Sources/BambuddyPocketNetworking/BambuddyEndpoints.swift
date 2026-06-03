// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Endpoints REST typés de l'API Bambuddy, exposés comme commodités sur tout `APIClient`.
/// Chemins relatifs au préfixe `/api/v1` (cf. `RequestFactory`).
public extension APIClient {
    /// Liste des imprimantes configurées sur le serveur (`GET /printers/`).
    func printers() async throws -> [Printer] {
        try await get("/printers/")
    }

    /// État temps réel complet d'une imprimante (`GET /printers/{id}/status`).
    func printerStatus(id: Int) async throws -> PrinterStatus {
        try await get("/printers/\(id)/status")
    }

    /// Requête `POST` sans réponse utile (actions de contrôle).
    func post(_ path: String, body: Data? = nil) async throws {
        let _: EmptyResponse = try await send(path, method: .post, body: body)
    }

    // MARK: Contrôles d'impression (cf. docs/bambuddy-api.md §7)

    /// Met l'impression en pause (`POST /printers/{id}/print/pause`).
    func pausePrint(id: Int) async throws {
        try await post("/printers/\(id)/print/pause")
    }

    /// Reprend l'impression (`POST /printers/{id}/print/resume`).
    func resumePrint(id: Int) async throws {
        try await post("/printers/\(id)/print/resume")
    }

    /// Arrête l'impression (`POST /printers/{id}/print/stop`).
    func stopPrint(id: Int) async throws {
        try await post("/printers/\(id)/print/stop")
    }

    /// Efface les erreurs HMS (`POST /printers/{id}/hms/clear`).
    func clearHMS(id: Int) async throws {
        try await post("/printers/\(id)/hms/clear")
    }
}
