// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Endpoints d'intégration **Bambu Cloud** et **MakerWorld**. Toutes ces routes sont gardées
/// côté serveur par une **session admin** (connexion par identifiants) : sous une simple clé d'API,
/// elles renvoient `401/403` → l'UI affiche « connexion admin requise » (cf. pattern #70) plutôt
/// qu'une erreur d'identifiants. Chemins relatifs au préfixe `/api/v1` (cf. `RequestFactory`).
public extension APIClient {
    // MARK: Bambu Cloud (cf. backend/app/api/routes/cloud.py)

    /// État d'authentification au compte Bambu Cloud (`GET /cloud/status`). Lecture seule :
    /// l'app n'affiche que l'état (connecté ? e-mail/région) ; le jeton vit côté serveur.
    func cloudStatus() async throws -> CloudAuthStatus {
        try await get("/cloud/status")
    }

    /// Lance une connexion au compte Bambu Cloud (`POST /cloud/login`). Si le compte exige une
    /// vérification, la réponse porte `needsVerification` et éventuellement un `tfaKey` à reporter
    /// dans `verifyCloud`.
    func loginCloud(_ request: CloudLoginRequest) async throws -> CloudLoginResponse {
        let body = try JSONEncoder.bambuddy().encode(request)
        return try await send("/cloud/login", method: .post, body: body)
    }

    /// Vérifie le code reçu par e-mail pour finaliser la connexion (`POST /cloud/verify`).
    func verifyCloud(_ request: CloudVerifyRequest) async throws -> CloudLoginResponse {
        let body = try JSONEncoder.bambuddy().encode(request)
        return try await send("/cloud/verify", method: .post, body: body)
    }

    /// Déconnecte le compte Bambu Cloud côté serveur (`POST /cloud/logout`).
    func logoutCloud() async throws {
        try await post("/cloud/logout")
    }

    // MARK: MakerWorld (cf. backend/app/api/routes/makerworld.py)

    /// État de l'intégration MakerWorld (`GET /makerworld/status`) : présence d'un jeton cloud et
    /// capacité de téléchargement.
    func makerWorldStatus() async throws -> MakerWorldStatus {
        try await get("/makerworld/status")
    }

    /// Imports récents depuis MakerWorld (`GET /makerworld/recent-imports`).
    func makerWorldRecentImports() async throws -> [MakerWorldRecentImport] {
        try await get("/makerworld/recent-imports")
    }

    /// Résout une URL publique MakerWorld en modèle importable (`POST /makerworld/resolve`).
    /// Opération de **lecture** (aucun téléchargement) : elle liste les plates/instances disponibles.
    func resolveMakerWorld(url: String) async throws -> MakerWorldResolvedModel {
        let body = try JSONEncoder.bambuddy().encode(MakerWorldResolveRequest(url: url))
        return try await send("/makerworld/resolve", method: .post, body: body)
    }

    /// Importe un modèle MakerWorld dans la bibliothèque serveur (`POST /makerworld/import`).
    /// ⚠️ Cette opération **télécharge** un 3MF côté serveur : à n'exécuter qu'en environnement
    /// de développement (Docker seedé), jamais sur un serveur de production.
    func importMakerWorld(_ request: MakerWorldImportRequest) async throws -> MakerWorldImportResponse {
        let body = try JSONEncoder.bambuddy().encode(request)
        return try await send("/makerworld/import", method: .post, body: body)
    }
}
