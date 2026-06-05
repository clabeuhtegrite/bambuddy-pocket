// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Fabrique un `RESTClient` configuré pour un serveur donné, en résolvant ses secrets via le
/// `SecretStore`, et fournit une sonde de test de connexion.
public struct ServerConnectionFactory: Sendable {
    private let secretStore: SecretStore
    private let session: URLSession

    public init(secretStore: SecretStore, session: URLSession = .shared) {
        self.secretStore = secretStore
        self.session = session
    }

    /// Construit un client REST authentifié pour ce serveur.
    public func makeClient(for configuration: ServerConfiguration) throws -> RESTClient {
        let secrets = try secretStore.secrets(for: configuration.id)
        return makeClient(for: configuration, secrets: secrets)
    }

    /// Construit un client REST avec des secrets **explicites** (sans passer par le store) —
    /// utile pour se connecter avant l'enregistrement du serveur (login user/pass).
    public func makeClient(for configuration: ServerConfiguration, secrets: ServerSecrets) -> RESTClient {
        let authorization = RequestAuthorization(configuration: configuration, secrets: secrets)
        let factory = RequestFactory(apiBaseURL: configuration.apiBaseURL, authorization: authorization)
        return RESTClient(factory: factory, session: session)
    }

    /// Construit le client WebSocket temps réel pour ce serveur (mêmes en-têtes auth/Cloudflare).
    ///
    /// Le `token` (frappé via `POST /auth/ws-token`), quand il est fourni, est ajouté en `?token=` :
    /// **requis** si l'auth est activée car le handshake WebSocket ne transporte pas l'en-tête
    /// `Authorization` — le serveur refuse alors la connexion (`close 4401`) sans ce jeton. Les
    /// en-têtes Cloudflare Access, eux, restent posés sur la requête d'upgrade.
    public func makeWebSocketClient(
        for configuration: ServerConfiguration,
        token: String? = nil
    ) throws -> WebSocketClient {
        guard var url = configuration.webSocketURL else { throw APIError.invalidURL }
        if let token, !token.isEmpty {
            url.append(queryItems: [URLQueryItem(name: "token", value: token)])
        }
        let secrets = try secretStore.secrets(for: configuration.id)
        let authorization = RequestAuthorization(configuration: configuration, secrets: secrets)
        return WebSocketClient(
            url: url,
            headers: authorization.headerFields,
            connector: URLSessionWebSocketConnector(session: session)
        )
    }

    /// Frappe un jeton WebSocket court (`POST /auth/ws-token`) à passer à `makeWebSocketClient`.
    /// Renvoie `nil` si l'auth est désactivée (jeton inutile) ou en cas d'échec — l'appelant tente
    /// alors une connexion sans jeton (valide uniquement sur instance non authentifiée).
    public func webSocketToken(for configuration: ServerConfiguration) async -> String? {
        guard configuration.authMethod != .none else { return nil }
        do {
            let client = try makeClient(for: configuration)
            return try await client.webSocketToken().token
        } catch {
            return nil
        }
    }

    /// Construit le client de flux caméra MJPEG pour une imprimante (mêmes en-têtes auth). Le jeton
    /// de flux, quand il est fourni, est ajouté en `?token=` — requis si l'auth est activée car le
    /// flux est chargé sans en-tête `Authorization` côté serveur.
    public func makeCameraStream(
        for configuration: ServerConfiguration,
        printerID: Int,
        token: String? = nil
    ) throws -> CameraStreamClient {
        let secrets = try secretStore.secrets(for: configuration.id)
        let authorization = RequestAuthorization(configuration: configuration, secrets: secrets)
        var url = configuration.apiBaseURL
            .appending(path: "printers")
            .appending(path: "\(printerID)")
            .appending(path: "camera")
            .appending(path: "stream")
        if let token, !token.isEmpty {
            url.append(queryItems: [URLQueryItem(name: "token", value: token)])
        }
        return CameraStreamClient(url: url, headers: authorization.headerFields, session: session)
    }

    /// Teste la connexion en interrogeant `/auth/status` (léger, ne requiert pas d'auth).
    /// Lève une `APIError` en cas d'échec (transport, HTTP, décodage).
    public func probe(_ configuration: ServerConfiguration) async throws -> AuthStatus {
        let client = try makeClient(for: configuration)
        return try await client.get("/auth/status")
    }
}
