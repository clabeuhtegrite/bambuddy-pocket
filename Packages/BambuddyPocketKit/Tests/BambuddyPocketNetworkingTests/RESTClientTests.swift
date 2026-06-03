// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation
import Testing
@testable import BambuddyPocketNetworking

private struct Echo: Decodable, Equatable {
    let message: String
}

/// Tests basés sur `MockURLProtocol`. **UNE seule suite sérialisée** : le mock utilise un état
/// statique partagé ; deux suites parallèles se marcheraient dessus (handler/lastRequest).
@Suite("Networking (mock URLProtocol)", .serialized)
struct MockNetworkingTests {
    private func makeClient(auth: RequestAuthorization = .none) throws -> RESTClient {
        let base = try #require(URL(string: "https://host.example.com/api/v1"))
        return RESTClient(factory: RequestFactory(apiBaseURL: base, authorization: auth), session: makeMockSession())
    }

    private func makeConfig() throws -> ServerConfiguration {
        try ServerConfiguration(
            label: "Atelier",
            baseURL: #require(URL(string: "https://host.example.com")),
            authMethod: .apiKey,
            usesCloudflareAccess: true
        )
    }

    private func respond(status: Int, json: String) {
        MockURLProtocol.requestHandler = { request in
            let url = request.url ?? URL(fileURLWithPath: "/")
            guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            else {
                throw URLError(.badServerResponse)
            }
            return (response, Data(json.utf8))
        }
    }

    // MARK: - RESTClient

    @Test("Injecte l'auth (Bearer + X-API-Key + Cloudflare) et construit l'URL")
    func injectsHeaders() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"message":"ok"}"#)
        let auth = RequestAuthorization(
            bearerToken: "JWT123",
            apiKey: "bb_key",
            cloudflareClientID: "cf-id",
            cloudflareClientSecret: "cf-secret"
        )
        let client = try makeClient(auth: auth)
        let _: Echo = try await client.send("/printers/", method: .get, body: nil)

        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer JWT123")
        #expect(request.value(forHTTPHeaderField: "X-API-Key") == "bb_key")
        #expect(request.value(forHTTPHeaderField: "CF-Access-Client-Id") == "cf-id")
        #expect(request.value(forHTTPHeaderField: "CF-Access-Client-Secret") == "cf-secret")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/")
    }

    @Test("Aucun en-tête d'auth quand .none")
    func noAuthHeaders() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"message":"ok"}"#)
        let client = try makeClient()
        let _: Echo = try await client.send("/printers/", method: .get, body: nil)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "X-API-Key") == nil)
        #expect(request.value(forHTTPHeaderField: "CF-Access-Client-Id") == nil)
    }

    @Test("Décode une réponse 200")
    func decodesSuccess() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"message":"bonjour"}"#)
        let client = try makeClient()
        let echo: Echo = try await client.send("/x", method: .get, body: nil)
        #expect(echo == Echo(message: "bonjour"))
    }

    @Test("401/403 → APIError.unauthorized")
    func unauthorized() async throws {
        MockURLProtocol.reset()
        respond(status: 401, json: #"{"detail":"nope"}"#)
        let client = try makeClient()
        await #expect(throws: APIError.unauthorized) {
            let _: Echo = try await client.send("/x", method: .get, body: nil)
        }
    }

    @Test("5xx → APIError.http(status:)")
    func serverError() async throws {
        MockURLProtocol.reset()
        respond(status: 503, json: #"{"detail":"down"}"#)
        let client = try makeClient()
        do {
            let _: Echo = try await client.send("/x", method: .get, body: nil)
            Issue.record("Une erreur était attendue")
        } catch let APIError.http(status, _) {
            #expect(status == 503)
        } catch {
            Issue.record("Erreur inattendue : \(error)")
        }
    }

    // MARK: - ServerConnectionFactory

    @Test("probe() interroge /auth/status avec les secrets injectés")
    func probeInjectsSecretsAndDecodes() async throws {
        MockURLProtocol.reset()
        let config = try makeConfig()
        let store = InMemorySecretStore()
        try store.setSecrets(
            ServerSecrets(apiKey: "bb_key", cloudflareClientID: "cf-id", cloudflareClientSecret: "cf-secret"),
            for: config.id
        )
        respond(status: 200, json: #"{"auth_enabled": true, "requires_setup": false}"#)

        let factory = ServerConnectionFactory(secretStore: store, session: makeMockSession())
        let status = try await factory.probe(config)
        #expect(status.authEnabled == true)
        #expect(status.requiresSetup == false)

        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/auth/status")
        #expect(request.value(forHTTPHeaderField: "X-API-Key") == "bb_key")
        #expect(request.value(forHTTPHeaderField: "CF-Access-Client-Id") == "cf-id")
    }

    @Test("probe() propage une erreur serveur")
    func probePropagatesError() async throws {
        MockURLProtocol.reset()
        let config = try makeConfig()
        respond(status: 500, json: "{}")
        let factory = ServerConnectionFactory(secretStore: InMemorySecretStore(), session: makeMockSession())
        await #expect(throws: APIError.self) {
            _ = try await factory.probe(config)
        }
    }

    // MARK: - Endpoints typés

    @Test("printers() cible /printers/ et décode la liste")
    func listsPrinters() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"[{"id":1,"name":"X1C","model":"X1 Carbon"}]"#)
        let client = try makeClient()
        let printers = try await client.printers()
        #expect(printers.map(\.id) == [1])
        #expect(printers.first?.name == "X1C")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/")
    }

    @Test("printerStatus(id:) cible /printers/{id}/status")
    func fetchesPrinterStatus() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"name":"X1C","state":"RUNNING","progress":42}"#)
        let client = try makeClient()
        let status = try await client.printerStatus(id: 9)
        #expect(status.state == .running)
        #expect(status.progress == 42)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/9/status")
    }

    @Test("pausePrint poste sur /print/pause")
    func pausesPrint() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.pausePrint(id: 4)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/4/print/pause")
    }

    @Test("archives() cible /archives/ et décode la liste")
    func listsArchives() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"[{"id":12,"status":"success","print_name":"Benchy","filament_used_grams":12.5}]"#)
        let client = try makeClient()
        let archives = try await client.archives()
        #expect(archives.map(\.id) == [12])
        #expect(archives.first?.printName == "Benchy")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/archives/")
    }

    @Test("cameraSnapshot cible /camera/snapshot et renvoie les données brutes")
    func fetchesCameraSnapshot() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "jpeg-bytes")
        let client = try makeClient()
        let data = try await client.cameraSnapshot(printerID: 2)
        #expect(data == Data("jpeg-bytes".utf8))
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/2/camera/snapshot")
    }

    @Test("queue() cible /queue/ et décode la liste")
    func listsQueue() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"[{"id":5,"position":1,"status":"pending","archive_name":"Gear"}]"#)
        let client = try makeClient()
        let items = try await client.queue()
        #expect(items.map(\.id) == [5])
        #expect(items.first?.displayName == "Gear")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/queue/")
    }

    @Test("activityLog() cible /notifications/logs et décode la liste")
    func listsActivity() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"id":3,"event_type":"print_complete","title":"Done","message":"Benchy finished","success":true}]"#
        )
        let client = try makeClient()
        let entries = try await client.activityLog()
        #expect(entries.map(\.id) == [3])
        #expect(entries.first?.eventType == "print_complete")
        #expect(entries.first?.success == true)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/notifications/logs")
    }

    @Test("reorderQueue poste sur /queue/reorder")
    func reordersQueue() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.reorderQueue([QueueReorderItem(id: 2, position: 1), QueueReorderItem(id: 1, position: 2)])
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/queue/reorder")
    }

    @Test("setChamberLight poste avec ?on=true")
    func setsChamberLight() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.setChamberLight(id: 3, on: true)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/3/chamber-light?on=true")
    }

    @Test("setPrintSpeed poste avec ?mode=3")
    func setsPrintSpeed() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.setPrintSpeed(id: 3, mode: 3)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/3/print-speed?mode=3")
    }

    @Test("login() poste les identifiants sur /auth/login")
    func performsLogin() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"access_token":"jwt-xyz","token_type":"bearer","requires_2fa":false}"#)
        let client = try makeClient()
        let response = try await client.login(username: "ad", password: "pw")
        #expect(response.accessToken == "jwt-xyz")
        #expect(response.needsTwoFactor == false)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/auth/login")
    }
}
