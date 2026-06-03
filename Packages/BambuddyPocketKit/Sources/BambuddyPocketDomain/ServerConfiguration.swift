// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Méthode d'authentification auprès d'une instance Bambuddy.
/// Voir `docs/bambuddy-api.md` §3 et `docs/adr/0003-connectivite-securite.md`.
public enum AuthMethod: String, Codable, Sendable, CaseIterable, Hashable {
    /// Instance sans authentification (auth désactivée côté serveur).
    case none
    /// Clé d'API (`X-API-Key` ou `Authorization: Bearer bb_…`).
    case apiKey
    /// Identifiants utilisateur (login → JWT, éventuellement 2FA).
    case userPassword
}

/// Configuration d'un serveur Bambuddy ajouté par l'utilisateur.
///
/// Ne contient **aucun secret** (clé d'API, mot de passe/JWT, secret Cloudflare) :
/// ceux-ci sont stockés séparément dans le Keychain, référencés par `id`.
public struct ServerConfiguration: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    /// Libellé affiché (ex. « Atelier », « Maison »).
    public var label: String
    /// URL racine du serveur : schéma + hôte + port (ex. `http://192.168.1.50:8000`).
    public var baseURL: URL
    /// Méthode d'authentification choisie.
    public var authMethod: AuthMethod
    /// Si vrai, les en-têtes Cloudflare Access (service token) sont envoyés sur **toutes**
    /// les requêtes (REST, WebSocket, caméra). Le secret est au Keychain.
    public var usesCloudflareAccess: Bool
    /// Autorise le HTTP en clair (uniquement attendu pour des hôtes locaux/privés).
    public var allowsInsecureLocalHTTP: Bool

    public init(
        id: UUID = UUID(),
        label: String,
        baseURL: URL,
        authMethod: AuthMethod = .none,
        usesCloudflareAccess: Bool = false,
        allowsInsecureLocalHTTP: Bool = false
    ) {
        self.id = id
        self.label = label
        self.baseURL = baseURL
        self.authMethod = authMethod
        self.usesCloudflareAccess = usesCloudflareAccess
        self.allowsInsecureLocalHTTP = allowsInsecureLocalHTTP
    }

    /// Préfixe de l'API REST Bambuddy.
    public static let apiPathPrefix = "/api/v1"

    /// Base des endpoints REST (`baseURL` + `/api/v1`).
    public var apiBaseURL: URL {
        baseURL.appending(path: "api").appending(path: "v1")
    }

    /// URL du flux WebSocket temps réel, dérivée de `baseURL`
    /// (`http`→`ws`, `https`→`wss`, même hôte/port, chemin `/api/v1/ws`).
    public var webSocketURL: URL? {
        guard var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }
        switch comps.scheme?.lowercased() {
        case "https": comps.scheme = "wss"
        case "http": comps.scheme = "ws"
        default: return nil
        }
        var basePath = comps.path
        if basePath.hasSuffix("/") { basePath.removeLast() }
        comps.path = basePath + "\(Self.apiPathPrefix)/ws"
        return comps.url
    }

    /// Indique si la connexion est en clair (HTTP) — l'UI doit alors avertir l'utilisateur.
    public var isInsecureTransport: Bool {
        baseURL.scheme?.lowercased() == "http"
    }
}
