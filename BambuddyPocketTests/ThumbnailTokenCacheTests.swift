// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// `URLProtocol` qui sert le jeton de flux (`POST …/printers/camera/stream-token`) et les vignettes
/// d'archive (`GET …/archives/{id}/thumbnail`), en **comptant les frappes de jeton** pour vérifier
/// la mise en cache.
private final class ThumbnailStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var tokenHits = 0
    nonisolated(unsafe) static var thumbnailHits = 0

    static func reset() {
        tokenHits = 0
        thumbnailHits = 0
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let body: Data
        if path.hasSuffix("/printers/camera/stream-token") {
            Self.tokenHits += 1
            body = Data(#"{"token":"tok-\#(Self.tokenHits)"}"#.utf8)
        } else if path.contains("/archives/"), path.hasSuffix("/thumbnail") {
            Self.thumbnailHits += 1
            body = Data([0xFF, 0xD8, 0xFF, 0xD9])
        } else {
            body = Data()
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/octet-stream"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func thumbnailStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ThumbnailStubURLProtocol.self]
    return URLSession(configuration: config)
}

/// Tests du **cache de jeton de vignette** (B1 #4) : les vignettes d'archive se chargent en rafale
/// et exigent chacune un `?token=` ; sans cache, chaque vignette déclenche un `POST` de jeton.
@MainActor
@Suite("Cache du jeton de vignette", .serialized)
struct ThumbnailTokenCacheTests {
    private func makeModel(authMethod: AuthMethod) throws -> ArchiveListModel {
        let environment = AppEnvironment.inMemory(session: thumbnailStubSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Atelier", baseURL: url, authMethod: authMethod)
        return ArchiveListModel(server: server, connectionFactory: environment.connectionFactory)
    }

    private func archive(_ id: Int) -> Archive {
        Archive(id: id, status: "completed")
    }

    @Test("Une rafale de vignettes ne frappe le jeton qu'une seule fois")
    func reusesTokenAcrossThumbnails() async throws {
        ThumbnailStubURLProtocol.reset()
        defer { ThumbnailStubURLProtocol.reset() }

        let model = try makeModel(authMethod: .apiKey)
        for id in 1 ... 5 {
            _ = await model.thumbnail(archive(id))
        }

        #expect(ThumbnailStubURLProtocol.thumbnailHits == 5)
        #expect(ThumbnailStubURLProtocol.tokenHits == 1)
    }

    @Test("Sans auth, aucune frappe de jeton n'est émise")
    func noTokenWhenAuthDisabled() async throws {
        ThumbnailStubURLProtocol.reset()
        defer { ThumbnailStubURLProtocol.reset() }

        let model = try makeModel(authMethod: .none)
        _ = await model.thumbnail(archive(1))
        _ = await model.thumbnail(archive(2))

        #expect(ThumbnailStubURLProtocol.thumbnailHits == 2)
        #expect(ThumbnailStubURLProtocol.tokenHits == 0)
    }
}
