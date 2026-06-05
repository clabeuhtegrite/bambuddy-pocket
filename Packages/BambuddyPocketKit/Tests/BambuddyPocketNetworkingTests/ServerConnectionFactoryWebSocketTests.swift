// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BambuddyPocketNetworking

/// Couvre la construction de l'URL WebSocket par `ServerConnectionFactory` : le jeton frappé via
/// `POST /auth/ws-token` doit être ajouté en `?token=` (requis quand l'auth est activée car le
/// handshake WebSocket ne transporte pas l'en-tête `Authorization`).
@Suite("ServerConnectionFactory · WebSocket")
struct ServerConnectionFactoryWebSocketTests {
    private func makeFactory(secrets: ServerSecrets) throws -> (ServerConnectionFactory, ServerConfiguration) {
        let store = InMemorySecretStore()
        let config = try ServerConfiguration(
            label: "Atelier",
            baseURL: #require(URL(string: "https://printers.example.com")),
            authMethod: .userPassword,
            usesCloudflareAccess: true
        )
        try store.setSecrets(secrets, for: config.id)
        return (ServerConnectionFactory(secretStore: store), config)
    }

    @Test("Ajoute le jeton en query ?token= quand il est fourni")
    func appendsTokenQuery() throws {
        let (factory, config) = try makeFactory(secrets: ServerSecrets(bearerToken: "jwt-abc"))
        let client = try factory.makeWebSocketClient(for: config, token: "ws-tok-123")
        let components = try #require(URLComponents(url: client.url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "wss")
        #expect(components.path == "/api/v1/ws")
        #expect(components.queryItems?.first(where: { $0.name == "token" })?.value == "ws-tok-123")
    }

    @Test("Sans jeton : URL /api/v1/ws nue (aucun query)")
    func noTokenNoQuery() throws {
        let (factory, config) = try makeFactory(secrets: ServerSecrets(bearerToken: "jwt-abc"))
        let client = try factory.makeWebSocketClient(for: config, token: nil)
        let components = try #require(URLComponents(url: client.url, resolvingAgainstBaseURL: false))
        #expect(components.path == "/api/v1/ws")
        #expect(components.queryItems == nil)
    }

    @Test("Un jeton vide n'ajoute pas de query")
    func emptyTokenIgnored() throws {
        let (factory, config) = try makeFactory(secrets: ServerSecrets(bearerToken: "jwt-abc"))
        let client = try factory.makeWebSocketClient(for: config, token: "")
        let components = try #require(URLComponents(url: client.url, resolvingAgainstBaseURL: false))
        #expect(components.queryItems == nil)
    }

    @Test("Les en-têtes auth + Cloudflare restent posés sur l'upgrade")
    func keepsAuthAndCloudflareHeaders() throws {
        let secrets = ServerSecrets(
            bearerToken: "jwt-abc",
            cloudflareClientID: "cf-id",
            cloudflareClientSecret: "cf-secret"
        )
        let (factory, config) = try makeFactory(secrets: secrets)
        let client = try factory.makeWebSocketClient(for: config, token: "ws-tok-123")
        #expect(client.headers["Authorization"] == "Bearer jwt-abc")
        #expect(client.headers["CF-Access-Client-Id"] == "cf-id")
        #expect(client.headers["CF-Access-Client-Secret"] == "cf-secret")
    }

    @Test("Le jeton est percent-encodé (caractères réservés URL)")
    func tokenPercentEncoded() throws {
        let (factory, config) = try makeFactory(secrets: ServerSecrets(bearerToken: "jwt-abc"))
        let client = try factory.makeWebSocketClient(for: config, token: "a b+c/d=e")
        let components = try #require(URLComponents(url: client.url, resolvingAgainstBaseURL: false))
        // La valeur décodée doit correspondre exactement au jeton d'origine.
        #expect(components.queryItems?.first(where: { $0.name == "token" })?.value == "a b+c/d=e")
        // Et la chaîne brute ne doit pas contenir l'espace littéral.
        #expect(!client.url.absoluteString.contains("a b+c"))
    }
}
