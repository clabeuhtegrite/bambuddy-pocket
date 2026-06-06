// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// `URLProtocol` minimal pour le test de pagination de l'archive : il distingue les pages par le
/// paramètre `offset` de la requête (`/archives/?limit=&offset=`) et compte les appels par offset.
private final class ArchivePageStubURLProtocol: URLProtocol {
    /// Réponse JSON indexée par valeur du paramètre `offset` (0, 50, …).
    nonisolated(unsafe) static var pages: [Int: Data] = [:]
    /// Nombre d'appels reçus par valeur d'`offset`.
    nonisolated(unsafe) static var hits: [Int: Int] = [:]

    static func reset() {
        pages = [:]
        hits = [:]
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    private static func offset(of request: URLRequest) -> Int {
        guard
            let url = request.url,
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let raw = components.queryItems?.first(where: { $0.name == "offset" })?.value,
            let value = Int(raw)
        else {
            return 0
        }
        return value
    }

    override func startLoading() {
        let offset = Self.offset(of: request)
        Self.hits[offset, default: 0] += 1
        let data = Self.pages[offset] ?? Data("[]".utf8)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func archiveStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ArchivePageStubURLProtocol.self]
    return URLSession(configuration: config)
}

/// Renvoie un JSON de `count` archives d'identifiants consécutifs à partir de `startID`.
private func archivePageJSON(startID: Int, count: Int) -> Data {
    let items = (0 ..< count)
        .map { #"{"id":\#(startID + $0),"status":"completed"}"# }
        .joined(separator: ",")
    return Data("[\(items)]".utf8)
}

/// Tests de la **pagination de l'archive** (#WIP wip-archive-pagination) : la première page pleine
/// déclenche le chargement de la page suivante, et une page incomplète arrête la pagination.
@MainActor
@Suite("Pagination de l'archive d'impressions", .serialized)
struct ArchivePaginationTests {
    private func makeModel(session: URLSession) throws -> ArchiveListModel {
        let environment = AppEnvironment.inMemory(session: session)
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Atelier", baseURL: url)
        return ArchiveListModel(server: server, connectionFactory: environment.connectionFactory)
    }

    /// Une première page **pleine** (50 éléments) doit signaler qu'il reste à charger ; la page 2
    /// est ensuite chargée et concaténée, et comme elle est incomplète la pagination s'arrête.
    @Test("Une première page pleine charge la page 2 puis s'arrête sur une page incomplète")
    func loadsSecondPageWhenFirstIsFull() async throws {
        ArchivePageStubURLProtocol.reset()
        defer { ArchivePageStubURLProtocol.reset() }
        ArchivePageStubURLProtocol.pages[0] = archivePageJSON(startID: 1, count: 50)
        ArchivePageStubURLProtocol.pages[50] = archivePageJSON(startID: 51, count: 20)

        let model = try makeModel(session: archiveStubSession())

        await model.load()
        #expect(model.archives.count == 50)
        #expect(model.canLoadMore)
        #expect(ArchivePageStubURLProtocol.hits[0] == 1)

        await model.loadMore()
        #expect(model.archives.count == 70)
        #expect(model.archives.map(\.id) == Array(1 ... 70))
        #expect(!model.canLoadMore)
        #expect(ArchivePageStubURLProtocol.hits[50] == 1)
    }

    /// Une première page **incomplète** (< pageSize) ne propose pas de charger plus, et `loadMore`
    /// reste un no-op (aucun appel supplémentaire au serveur).
    @Test("Une première page incomplète n'autorise pas de charger plus")
    func incompleteFirstPageStopsPagination() async throws {
        ArchivePageStubURLProtocol.reset()
        defer { ArchivePageStubURLProtocol.reset() }
        ArchivePageStubURLProtocol.pages[0] = archivePageJSON(startID: 1, count: 3)

        let model = try makeModel(session: archiveStubSession())

        await model.load()
        #expect(model.archives.count == 3)
        #expect(!model.canLoadMore)

        await model.loadMore()
        #expect(model.archives.count == 3)
        #expect(ArchivePageStubURLProtocol.hits[3] == nil)
    }

    /// La page suivante est **dédoublonnée** par identifiant : un chevauchement entre pages (le
    /// serveur peut renvoyer un élément déjà vu si des archives ont été insérées) n'ajoute pas de
    /// doublon.
    @Test("La page suivante est dédoublonnée par identifiant")
    func deduplicatesOverlappingPages() async throws {
        ArchivePageStubURLProtocol.reset()
        defer { ArchivePageStubURLProtocol.reset() }
        ArchivePageStubURLProtocol.pages[0] = archivePageJSON(startID: 1, count: 50)
        // La page 2 ré-inclut l'id 50 (chevauchement) puis de nouveaux éléments.
        ArchivePageStubURLProtocol.pages[50] = archivePageJSON(startID: 50, count: 10)

        let model = try makeModel(session: archiveStubSession())

        await model.load()
        await model.loadMore()

        #expect(model.archives.count == 59)
        #expect(Set(model.archives.map(\.id)).count == 59)
    }
}
