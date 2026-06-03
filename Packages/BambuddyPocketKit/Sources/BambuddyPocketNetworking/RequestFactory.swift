// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// En-têtes d'autorisation à injecter sur les requêtes (résolus depuis le Keychain par une
/// couche supérieure). Voir `docs/adr/0003-connectivite-securite.md`.
public struct RequestAuthorization: Sendable, Hashable {
    /// JWT ou clé d'API préfixée `bb_` → `Authorization: Bearer …`.
    public var bearerToken: String?
    /// Clé d'API → `X-API-Key: …`.
    public var apiKey: String?
    /// Cloudflare Access (service token) → `CF-Access-Client-Id`.
    public var cloudflareClientID: String?
    /// Cloudflare Access (service token) → `CF-Access-Client-Secret`.
    public var cloudflareClientSecret: String?

    public init(
        bearerToken: String? = nil,
        apiKey: String? = nil,
        cloudflareClientID: String? = nil,
        cloudflareClientSecret: String? = nil
    ) {
        self.bearerToken = bearerToken
        self.apiKey = apiKey
        self.cloudflareClientID = cloudflareClientID
        self.cloudflareClientSecret = cloudflareClientSecret
    }

    public static let none = RequestAuthorization()
}

/// Construit les `URLRequest` vers l'API Bambuddy en injectant de façon centralisée l'auth
/// (Bearer / X-API-Key) **et** les en-têtes Cloudflare Access sur **toutes** les requêtes.
public struct RequestFactory: Sendable {
    /// Base REST, incluant le préfixe `/api/v1` (cf. `ServerConfiguration.apiBaseURL`).
    public let apiBaseURL: URL
    public var authorization: RequestAuthorization

    public init(apiBaseURL: URL, authorization: RequestAuthorization = .none) {
        self.apiBaseURL = apiBaseURL
        self.authorization = authorization
    }

    /// Construit une requête vers `path` (relatif au préfixe `/api/v1`, ex. `/printers/`).
    public func makeRequest(path: String, method: HTTPMethod = .get, body: Data? = nil) -> URLRequest {
        let normalized = path.hasPrefix("/") ? path : "/" + path
        let url = URL(string: apiBaseURL.absoluteString + normalized) ?? apiBaseURL
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let bearer = authorization.bearerToken {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        if let key = authorization.apiKey {
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        }
        if let clientID = authorization.cloudflareClientID {
            request.setValue(clientID, forHTTPHeaderField: "CF-Access-Client-Id")
        }
        if let clientSecret = authorization.cloudflareClientSecret {
            request.setValue(clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        }
        return request
    }
}
