// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// `URLProtocol` minimal pour mocker les réponses REST dans le test-cible app (le mock du paquet
/// réseau n'est pas visible ici).
private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [String: (Int, Data)] = [:]

    static func reset() {
        responses = [:]
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    private static func normalize(_ path: String) -> String {
        path.hasSuffix("/") && path.count > 1 ? String(path.dropLast()) : path
    }

    override func startLoading() {
        let path = Self.normalize(request.url?.path ?? "")
        let match = Self.responses.first { Self.normalize($0.key) == path }?.value
        let (status, data) = match ?? (404, Data())
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func stubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

@MainActor
@Suite("Repli REST du temps réel", .serialized)
struct RealtimeRESTFallbackTests {
    /// Sans WebSocket, `refreshFromREST()` doit peupler les statuts vivants depuis
    /// `GET /printers/{id}/status` — c'est ce qui fait apparaître l'état/les sections live
    /// quand le WebSocket est bloqué (ex. proxy Cloudflare refusant l'upgrade).
    @Test("refreshFromREST amorce les statuts via GET /printers/{id}/status")
    func seedsStatusesFromREST() async throws {
        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        StubURLProtocol.responses["/api/v1/printers/"] = (
            200,
            Data(#"[{"id":1,"name":"X2D","model":"X2D"}]"#.utf8)
        )
        StubURLProtocol.responses["/api/v1/printers/1/status"] = (
            200,
            Data(#"{"id":1,"name":"X2D","connected":true,"state":"RUNNING","progress":42}"#.utf8)
        )

        let environment = AppEnvironment.inMemory(session: stubSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Prof", baseURL: url)
        let center = ServerNotificationCenter(
            server: server,
            connectionFactory: environment.connectionFactory
        )

        #expect(center.status(for: 1) == nil)
        await center.refreshFromREST()

        let status = try #require(center.status(for: 1))
        #expect(status.connected == true)
        #expect(status.state == .running)
        #expect(status.progress == 42)
    }

    /// **Retour device A2** : dès le **premier statut frais** obtenu par REST, le badge quitte
    /// « Connexion… » (`.connecting`) pour « En direct » sain (`.restMode`) — sans attendre que le
    /// handshake WebSocket aboutisse ou échoue (~15 s).
    @Test("Le premier statut REST frais promeut le badge connecting → restMode")
    func firstFreshRESTPromotesBadge() async throws {
        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        StubURLProtocol.responses["/api/v1/printers/"] = (
            200,
            Data(#"[{"id":1,"name":"X2D","model":"X2D"}]"#.utf8)
        )
        StubURLProtocol.responses["/api/v1/printers/1/status"] = (
            200,
            Data(#"{"id":1,"name":"X2D","connected":true,"state":"RUNNING"}"#.utf8)
        )

        let environment = AppEnvironment.inMemory(session: stubSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Prof", baseURL: url)
        let center = ServerNotificationCenter(
            server: server,
            connectionFactory: environment.connectionFactory
        )

        #expect(center.realtimeState == .connecting)
        await center.refreshFromREST()
        #expect(center.realtimeState == .restMode)
    }

    /// Sans statut frais (réseau en échec), le badge **ne doit pas** être promu : il reste en
    /// « Connexion… » (on ne ment pas sur la disponibilité des données).
    @Test("Sans statut frais, le badge reste connecting")
    func noPromotionWithoutFreshStatus() async throws {
        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        // Aucune réponse enregistrée → 404 partout, donc aucun statut frais.
        let environment = AppEnvironment.inMemory(session: stubSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Prof", baseURL: url)
        let center = ServerNotificationCenter(
            server: server,
            connectionFactory: environment.connectionFactory
        )

        #expect(center.realtimeState == .connecting)
        await center.refreshFromREST()
        #expect(center.realtimeState == .connecting)
    }

    /// Le repli ne doit jamais lever ni planter quand le réseau échoue : l'état reste simplement
    /// vide (l'UI affichera « Inconnu », sans bannière d'erreur trompeuse).
    @Test("refreshFromREST est silencieux en cas d'échec réseau")
    func silentOnFailure() async throws {
        StubURLProtocol.reset()
        defer { StubURLProtocol.reset() }
        // Aucune réponse enregistrée → 404 partout.
        let environment = AppEnvironment.inMemory(session: stubSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Prof", baseURL: url)
        let center = ServerNotificationCenter(
            server: server,
            connectionFactory: environment.connectionFactory
        )

        await center.refreshFromREST()
        #expect(center.status(for: 1) == nil)
    }
}
