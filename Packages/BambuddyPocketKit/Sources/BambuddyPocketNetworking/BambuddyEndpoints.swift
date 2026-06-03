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

    /// Ajoute une imprimante côté serveur (`POST /printers/`).
    func createPrinter(_ printer: PrinterCreate) async throws -> Printer {
        let body = try JSONEncoder.bambuddy().encode(printer)
        return try await send("/printers/", method: .post, body: body)
    }

    /// Archive d'impressions (`GET /archives/`), la plus récente d'abord côté serveur.
    func archives() async throws -> [Archive] {
        try await get("/archives/")
    }

    /// Détail d'une archive (`GET /archives/{id}`).
    func archive(id: Int) async throws -> Archive {
        try await get("/archives/\(id)")
    }

    /// File d'attente d'impression (`GET /queue/`).
    func queue() async throws -> [QueueItem] {
        try await get("/queue/")
    }

    /// Flux d'activité du serveur (`GET /notifications/logs`).
    func activityLog() async throws -> [ActivityEntry] {
        try await get("/notifications/logs")
    }

    /// Inventaire des bobines de filament (`GET /inventory/spools`).
    func inventorySpools() async throws -> [Spool] {
        try await get("/inventory/spools")
    }

    /// Fichiers de la bibliothèque de modèles (`GET /library/files/`).
    func libraryFiles() async throws -> [LibraryFile] {
        try await get("/library/files/")
    }

    /// Projets d'impression (`GET /projects/`).
    func projects() async throws -> [Project] {
        try await get("/projects/")
    }

    /// Réordonne la file d'attente (`POST /queue/reorder`).
    func reorderQueue(_ items: [QueueReorderItem]) async throws {
        let body = try JSONEncoder.bambuddy().encode(QueueReorder(items: items))
        try await post("/queue/reorder", body: body)
    }

    /// Ajoute un élément à la file (`POST /queue/`).
    func addToQueue(_ item: QueueItemCreate) async throws {
        let body = try JSONEncoder.bambuddy().encode(item)
        try await post("/queue/", body: body)
    }

    // MARK: Authentification (cf. docs/bambuddy-api.md §3)

    /// Connexion par identifiants (`POST /auth/login`).
    func login(username: String, password: String) async throws -> LoginResponse {
        let body = try JSONEncoder.bambuddy().encode(LoginRequest(username: username, password: password))
        return try await send("/auth/login", method: .post, body: body)
    }

    /// Vérification du second facteur (`POST /auth/2fa/verify`).
    func verifyTwoFactor(preAuthToken: String, code: String, method: String?) async throws -> TwoFAVerifyResponse {
        let request = TwoFAVerifyRequest(preAuthToken: preAuthToken, code: code, method: method)
        let body = try JSONEncoder.bambuddy().encode(request)
        return try await send("/auth/2fa/verify", method: .post, body: body)
    }

    /// Utilisateur courant — valide le token (`GET /auth/me`).
    func currentUser() async throws -> User {
        try await get("/auth/me")
    }

    /// Requête `POST` sans réponse utile (actions de contrôle).
    func post(_ path: String, body: Data? = nil) async throws {
        let _: EmptyResponse = try await send(path, method: .post, body: body)
    }

    /// Requête `DELETE` sans réponse utile.
    func delete(_ path: String) async throws {
        let _: EmptyResponse = try await send(path, method: .delete, body: nil)
    }

    // MARK: Actions sur la file

    /// Démarre un élément de la file (`POST /queue/{id}/start`).
    func startQueueItem(id: Int) async throws {
        try await post("/queue/\(id)/start")
    }

    /// Annule un élément de la file (`POST /queue/{id}/cancel`).
    func cancelQueueItem(id: Int) async throws {
        try await post("/queue/\(id)/cancel")
    }

    /// Supprime un élément de la file (`DELETE /queue/{id}`).
    func deleteQueueItem(id: Int) async throws {
        try await delete("/queue/\(id)")
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

    /// Allume/éteint la lumière de chambre (`POST /printers/{id}/chamber-light?on=<bool>`).
    func setChamberLight(id: Int, on: Bool) async throws {
        try await post("/printers/\(id)/chamber-light?on=\(on)")
    }

    /// Règle la vitesse d'impression (`POST /printers/{id}/print-speed?mode=<1…4>`).
    func setPrintSpeed(id: Int, mode: Int) async throws {
        try await post("/printers/\(id)/print-speed?mode=\(mode)")
    }

    /// Décharge le filament courant (`POST /printers/{id}/ams/unload`).
    func amsUnload(id: Int) async throws {
        try await post("/printers/\(id)/ams/unload")
    }

    /// Démarre le séchage d'une unité AMS (`POST /printers/{id}/drying/start?ams_id=<int>`).
    func startDrying(id: Int, amsID: Int) async throws {
        try await post("/printers/\(id)/drying/start?ams_id=\(amsID)")
    }

    /// Arrête le séchage d'une unité AMS (`POST /printers/{id}/drying/stop?ams_id=<int>`).
    func stopDrying(id: Int, amsID: Int) async throws {
        try await post("/printers/\(id)/drying/stop?ams_id=\(amsID)")
    }
}
