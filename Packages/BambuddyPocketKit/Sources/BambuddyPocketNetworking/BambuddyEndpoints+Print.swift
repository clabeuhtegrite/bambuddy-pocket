// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Endpoints de **lancement d'impression** (depuis un fichier de bibliothèque ou une archive).
/// `printer_id` est toujours passé en **query** (contrat amont vérifié) ; les options vont dans le
/// corps. Le serveur dispatche le send/start de façon asynchrone et renvoie l'état de mise en file.
public extension APIClient {
    /// Lance l'impression d'un fichier de bibliothèque **tranché** (`POST /library/files/{id}/print`).
    /// Permission requise : `PRINTERS_CONTROL`.
    @discardableResult
    func printLibraryFile(
        id: Int,
        printerID: Int,
        request: FilePrintRequest
    ) async throws -> PrintDispatchResult {
        let body = try JSONEncoder.bambuddy().encode(request)
        return try await send("/library/files/\(id)/print?printer_id=\(printerID)", method: .post, body: body)
    }

    /// Réimprime une archive (`POST /archives/{id}/reprint`). `printer_id` est passé en **query**.
    /// Permission requise : `ARCHIVES_REPRINT_ALL`/`ARCHIVES_REPRINT_OWN`.
    @discardableResult
    func reprintArchive(
        id: Int,
        printerID: Int,
        request: ReprintRequest
    ) async throws -> PrintDispatchResult {
        let body = try JSONEncoder.bambuddy().encode(request)
        return try await send("/archives/\(id)/reprint?printer_id=\(printerID)", method: .post, body: body)
    }
}
