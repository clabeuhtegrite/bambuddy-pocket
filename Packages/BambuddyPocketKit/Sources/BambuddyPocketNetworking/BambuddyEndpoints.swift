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
