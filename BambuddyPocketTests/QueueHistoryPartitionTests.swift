// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// `GET /queue/` renvoie les éléments actifs **et** terminaux mélangés (comme le tableau de bord
/// web). `QueueListModel` doit les séparer en « File » (actifs, ordonnés) et « Historique »
/// (terminaux, du plus récent au plus ancien) — l'« Historique (N) » manquant côté app.
private final class QueueStubURLProtocol: URLProtocol {
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
        let (status, data) = match ?? (200, Data("[]".utf8))
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
    config.protocolClasses = [QueueStubURLProtocol.self]
    return URLSession(configuration: config)
}

@MainActor
@Suite("Historique de la file (partition active / terminale)", .serialized)
struct QueueHistoryPartitionTests {
    private func makeModel() throws -> QueueListModel {
        let environment = AppEnvironment.inMemory(session: stubSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Prof", baseURL: url)
        return QueueListModel(server: server, connectionFactory: environment.connectionFactory)
    }

    @Test("Sépare les éléments actifs (File) des terminaux (Historique)")
    func partitionsActiveAndHistory() async throws {
        QueueStubURLProtocol.reset()
        defer { QueueStubURLProtocol.reset() }
        // 2 actifs (pending/printing) + 3 terminaux (completed/failed/cancelled).
        QueueStubURLProtocol.responses["/api/v1/queue/"] = (200, Data(#"""
        [
          {"id":10,"position":1,"status":"printing","archive_name":"A"},
          {"id":11,"position":2,"status":"pending","archive_name":"B"},
          {"id":7,"position":1,"status":"completed","archive_name":"Old1"},
          {"id":9,"position":1,"status":"cancelled","archive_name":"Old2"},
          {"id":8,"position":1,"status":"failed","archive_name":"Old3"}
        ]
        """#.utf8))
        QueueStubURLProtocol.responses["/api/v1/queue/batches"] = (200, Data("[]".utf8))
        QueueStubURLProtocol.responses["/api/v1/printers/"] = (200, Data("[]".utf8))

        let model = try makeModel()
        await model.load()

        #expect(model.activeItems.map(\.id) == [10, 11])
        // Historique : terminaux uniquement, triés id décroissant (plus récent d'abord).
        #expect(model.historyItems.map(\.id) == [9, 8, 7])
        let allHistoryTerminal = model.historyItems.allSatisfy(\.isTerminal)
        let noActiveTerminal = model.activeItems.allSatisfy { !$0.isTerminal }
        #expect(allHistoryTerminal)
        #expect(noActiveTerminal)
    }

    @Test("File vide mais historique présent : seul l'historique s'affiche")
    func onlyHistory() async throws {
        QueueStubURLProtocol.reset()
        defer { QueueStubURLProtocol.reset() }
        QueueStubURLProtocol.responses["/api/v1/queue/"] = (200, Data(#"""
        [{"id":1,"position":1,"status":"completed","archive_name":"Done"}]
        """#.utf8))
        QueueStubURLProtocol.responses["/api/v1/queue/batches"] = (200, Data("[]".utf8))
        QueueStubURLProtocol.responses["/api/v1/printers/"] = (200, Data("[]".utf8))

        let model = try makeModel()
        await model.load()

        #expect(model.activeItems.isEmpty)
        #expect(model.historyItems.map(\.id) == [1])
    }
}
