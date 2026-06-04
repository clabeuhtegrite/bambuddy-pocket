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

    /// En-têtes HTTP correspondants (auth + Cloudflare Access), à appliquer de façon identique
    /// sur **toutes** les surfaces : REST, WebSocket et caméra.
    public var headerFields: [String: String] {
        var fields: [String: String] = [:]
        if let bearerToken {
            fields["Authorization"] = "Bearer \(bearerToken)"
        }
        if let apiKey {
            fields["X-API-Key"] = apiKey
        }
        if let cloudflareClientID {
            fields["CF-Access-Client-Id"] = cloudflareClientID
        }
        if let cloudflareClientSecret {
            fields["CF-Access-Client-Secret"] = cloudflareClientSecret
        }
        return fields
    }
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

    /// Construit une requête vers `path` (relatif au préfixe `/api/v1`, ex. `/printers/`). Le type
    /// de contenu par défaut est `application/json` ; passer `contentType` pour un autre corps
    /// (ex. `multipart/form-data` pour un téléversement de fichier).
    public func makeRequest(
        path: String,
        method: HTTPMethod = .get,
        body: Data? = nil,
        contentType: String = "application/json"
    ) -> URLRequest {
        let normalized = path.hasPrefix("/") ? path : "/" + path
        let url = URL(string: apiBaseURL.absoluteString + normalized) ?? apiBaseURL
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = body
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        for (field, value) in authorization.headerFields {
            request.setValue(value, forHTTPHeaderField: field)
        }
        return request
    }
}
