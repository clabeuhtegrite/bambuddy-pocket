// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Méthodes HTTP utilisées par l'API Bambuddy.
public enum HTTPMethod: String, Sendable, Hashable {
    case get = "GET"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
    case delete = "DELETE"
}

/// Erreurs de la couche réseau.
public enum APIError: Error, Sendable, Equatable {
    case invalidURL
    case transport(String)
    /// `401` : authentification absente/invalide → l'utilisateur doit vérifier ses identifiants.
    case unauthorized
    /// `403` : authentifié mais **non autorisé**. Le cas courant côté Bambuddy est une **clé d'API**
    /// qui tente une fonction réservée à une **session par identifiants** (gestion des clés d'API,
    /// sauvegardes locales et distantes). Ce comportement est **volontaire** côté serveur — ce n'est
    /// **pas** un problème d'identifiants. `reason` reprend le `detail` du serveur quand il existe.
    case forbidden(reason: String?)
    case http(status: Int, body: String?)
    case decoding(String)
    case server(message: String)
}

public extension APIError {
    /// `true` pour un `403` : fonction réservée à une connexion par identifiants (admin). L'UI doit
    /// afficher un message d'orientation clair plutôt qu'une erreur d'identifiants, et **masquer**
    /// les actions associées (créer une clé, sauvegarder, configurer…).
    var isForbidden: Bool {
        if case .forbidden = self { return true }
        return false
    }

    /// `true` quand le serveur a répondu `404` : la **fonctionnalité n'existe pas / n'est pas
    /// activée** sur ce serveur. Ce n'est **pas** une erreur d'authentification — l'UI doit afficher
    /// un état « non disponible » plutôt qu'une erreur, et masquer les actions associées.
    var isNotFound: Bool {
        if case let .http(status, _) = self, status == 404 { return true }
        return false
    }

    /// `true` quand le serveur a répondu `409` (conflit) : l'**état désiré est déjà atteint**
    /// (ex. « AMS already drying », lumière déjà dans l'état demandé). Du point de vue de
    /// l'utilisateur, l'action a réussi — l'UI doit traiter ce cas comme un **no-op** (pas d'erreur
    /// affichée) et simplement rafraîchir le statut pour resynchroniser le toggle.
    var isConflict: Bool {
        if case let .http(status, _) = self, status == 409 { return true }
        return false
    }
}

/// Contrat d'un client REST Bambuddy. L'implémentation concrète (URLSession, injection des
/// en-têtes d'auth + Cloudflare Access) arrive dans la couche réseau de la Phase 0.
public protocol APIClient: Sendable {
    /// Envoie une requête et décode la réponse JSON.
    /// - Parameters:
    ///   - path: chemin relatif au préfixe `/api/v1` (ex. `/printers/`).
    ///   - method: méthode HTTP.
    ///   - body: corps JSON éventuel.
    func send<Response: Decodable & Sendable>(
        _ path: String,
        method: HTTPMethod,
        body: Data?
    ) async throws -> Response
}

public extension APIClient {
    /// Raccourci pour un GET sans corps.
    func get<Response: Decodable & Sendable>(_ path: String) async throws -> Response {
        try await send(path, method: .get, body: nil)
    }
}
