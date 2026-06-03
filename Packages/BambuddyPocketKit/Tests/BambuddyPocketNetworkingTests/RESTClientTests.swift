// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketNetworking

private struct Echo: Decodable, Equatable {
    let message: String
}

@Suite("RESTClient", .serialized)
struct RESTClientTests {
    private func makeClient(auth: RequestAuthorization = .none) -> RESTClient {
        // swiftlint:disable:next force_unwrapping
        let base = URL(string: "https://host.example.com/api/v1")!
        return RESTClient(factory: RequestFactory(apiBaseURL: base, authorization: auth), session: makeMockSession())
    }

    private func respond(status: Int, json: String) {
        MockURLProtocol.requestHandler = { request in
            // swiftlint:disable:next force_unwrapping
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }
    }

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
        let client = makeClient(auth: auth)
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
        let client = makeClient()
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
        let client = makeClient()
        let echo: Echo = try await client.send("/x", method: .get, body: nil)
        #expect(echo == Echo(message: "bonjour"))
    }

    @Test("401/403 → APIError.unauthorized")
    func unauthorized() async throws {
        MockURLProtocol.reset()
        respond(status: 401, json: #"{"detail":"nope"}"#)
        let client = makeClient()
        await #expect(throws: APIError.unauthorized) {
            let _: Echo = try await client.send("/x", method: .get, body: nil)
        }
    }

    @Test("5xx → APIError.http(status:)")
    func serverError() async throws {
        MockURLProtocol.reset()
        respond(status: 503, json: #"{"detail":"down"}"#)
        let client = makeClient()
        do {
            let _: Echo = try await client.send("/x", method: .get, body: nil)
            Issue.record("Une erreur était attendue")
        } catch let APIError.http(status, _) {
            #expect(status == 503)
        } catch {
            Issue.record("Erreur inattendue : \(error)")
        }
    }
}
