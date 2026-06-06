// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// `URLProtocol` qui **compte** les requêtes par chemin, pour vérifier le coalescing des sondages
/// de statut (le repli global, le sondage rapide et le re-fetch post-action visent la même
/// imprimante : on ne veut pas de `GET /printers/{id}/status` redondants).
private final class CountingURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [String: (Int, Data)] = [:]
    nonisolated(unsafe) static var counts: [String: Int] = [:]
    private nonisolated(unsafe) static let lock = NSLock()

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        responses = [:]
        counts = [:]
    }

    static func count(for path: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counts[normalize(path)] ?? 0
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
        Self.lock.lock()
        Self.counts[path, default: 0] += 1
        let match = Self.responses.first { Self.normalize($0.key) == path }?.value
        Self.lock.unlock()
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

private func countingSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [CountingURLProtocol.self]
    return URLSession(configuration: config)
}

@MainActor
@Suite("Coalescing des sondages de statut", .serialized)
struct StatusPollingCoalescingTests {
    private func makeCenter() throws -> ServerNotificationCenter {
        let environment = AppEnvironment.inMemory(session: countingSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Prof", baseURL: url)
        return ServerNotificationCenter(server: server, connectionFactory: environment.connectionFactory)
    }

    private func seedOnePrinter() {
        CountingURLProtocol.responses["/api/v1/printers/"] = (
            200,
            Data(#"[{"id":1,"name":"X2D","model":"X2D"}]"#.utf8)
        )
        CountingURLProtocol.responses["/api/v1/printers/1/status"] = (
            200,
            Data(#"{"id":1,"name":"X2D","connected":true,"state":"RUNNING"}"#.utf8)
        )
    }

    /// Deux re-fetch ciblés rapprochés (non forcés) ⇒ un seul vrai `GET` : le second est sauté car
    /// le statut vient d'être rafraîchi (intervalle minimal).
    @Test("Deux refreshStatus rapprochés ⇒ un seul GET (coalescing)")
    func coalescesCloseRefreshes() async throws {
        CountingURLProtocol.reset()
        defer { CountingURLProtocol.reset() }
        seedOnePrinter()
        let center = try makeCenter()

        await center.refreshStatus(for: 1)
        await center.refreshStatus(for: 1)

        #expect(CountingURLProtocol.count(for: "/api/v1/printers/1/status") == 1)
        #expect(center.status(for: 1)?.state == .running)
    }

    /// Un re-fetch **forcé** (post-action A1) outrepasse le coalescing : il refait toujours le `GET`.
    @Test("refreshStatus(force: true) outrepasse le coalescing")
    func forceBypassesCoalescing() async throws {
        CountingURLProtocol.reset()
        defer { CountingURLProtocol.reset() }
        seedOnePrinter()
        let center = try makeCenter()

        await center.refreshStatus(for: 1)
        await center.refreshStatus(for: 1, force: true)

        #expect(CountingURLProtocol.count(for: "/api/v1/printers/1/status") == 2)
    }

    /// Le repli global ne re-poll pas une imprimante déjà couverte par le sondage rapide
    /// (`beginObserving`) : pas de doublon de `GET /printers/{id}/status`.
    @Test("refreshFromREST saute les imprimantes activement observées")
    func skipsActivelyObservedPrinters() async throws {
        CountingURLProtocol.reset()
        defer { CountingURLProtocol.reset() }
        seedOnePrinter()
        let center = try makeCenter()

        // Amorce le cache de liste sans encore frapper de statut.
        await center.refreshFromREST()
        let baseline = CountingURLProtocol.count(for: "/api/v1/printers/1/status")

        center.beginObserving(printerID: 1) // l'imprimante 1 est désormais couverte par le sondage rapide
        // Attendre que le coalescing expire pour isoler l'effet « active set » (et non l'intervalle).
        try await Task.sleep(for: .seconds(2.2))
        await center.refreshFromREST()

        // Aucun GET de statut supplémentaire pour l'imprimante active via le repli global.
        #expect(CountingURLProtocol.count(for: "/api/v1/printers/1/status") == baseline)
        center.endObserving(printerID: 1)
    }

    /// Le repli global ne re-télécharge pas `printers()` à chaque tick : la liste est mise en cache.
    @Test("refreshFromREST ne re-télécharge pas la liste à chaque tick")
    func cachesPrinterList() async throws {
        CountingURLProtocol.reset()
        defer { CountingURLProtocol.reset() }
        seedOnePrinter()
        let center = try makeCenter()

        await center.refreshFromREST()
        try await Task.sleep(for: .seconds(2.2)) // dépasse l'intervalle de coalescing du statut
        await center.refreshFromREST()

        // La liste (`GET /printers/`) n'est frappée qu'une fois malgré deux replis.
        #expect(CountingURLProtocol.count(for: "/api/v1/printers/") == 1)
        // Le statut, lui, est bien re-sondé au second repli (coalescing expiré).
        #expect(CountingURLProtocol.count(for: "/api/v1/printers/1/status") == 2)
    }

    /// Un chargement explicite (`updatePrinterList`) ré-amorce le cache : le repli suivant n'a pas
    /// besoin de re-télécharger la liste.
    @Test("updatePrinterList amorce le cache de liste sans GET /printers/")
    func explicitListUpdateSeedsCache() async throws {
        CountingURLProtocol.reset()
        defer { CountingURLProtocol.reset() }
        seedOnePrinter()
        let center = try makeCenter()

        center.updatePrinterList([Printer(id: 1, name: "X2D")])
        await center.refreshFromREST()

        #expect(CountingURLProtocol.count(for: "/api/v1/printers/") == 0)
        #expect(CountingURLProtocol.count(for: "/api/v1/printers/1/status") == 1)
    }
}
