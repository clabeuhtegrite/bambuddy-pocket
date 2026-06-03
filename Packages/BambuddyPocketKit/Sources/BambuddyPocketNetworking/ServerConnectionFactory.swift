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
        let authorization = RequestAuthorization(configuration: configuration, secrets: secrets)
        let factory = RequestFactory(apiBaseURL: configuration.apiBaseURL, authorization: authorization)
        return RESTClient(factory: factory, session: session)
    }

    /// Teste la connexion en interrogeant `/auth/status` (léger, ne requiert pas d'auth).
    /// Lève une `APIError` en cas d'échec (transport, HTTP, décodage).
    public func probe(_ configuration: ServerConfiguration) async throws -> AuthStatus {
        let client = try makeClient(for: configuration)
        return try await client.get("/auth/status")
    }
}
