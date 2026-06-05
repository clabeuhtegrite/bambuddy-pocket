// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// `URLProtocol` qui **refuse l'upgrade WebSocket** (réponse non-101) pour simuler un proxy
/// (type Cloudflare Access) qui bloque le temps réel, tout en répondant au REST de repli.
private final class WSRefusingURLProtocol: URLProtocol {
    nonisolated(unsafe) static var restResponses: [String: (Int, Data)] = [:]

    static func reset() {
        restResponses = [:]
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
        let isUpgrade = (request.value(forHTTPHeaderField: "Upgrade")?.lowercased() == "websocket")
            || request.url?.scheme?.hasPrefix("ws") == true
        if isUpgrade {
            // Upgrade refusé : 403 (comme Cloudflare Access). La socket lèvera à la réception.
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 403,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        let path = Self.normalize(request.url?.path ?? "")
        let match = Self.restResponses.first { Self.normalize($0.key) == path }?.value
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
    config.protocolClasses = [WSRefusingURLProtocol.self]
    return URLSession(configuration: config)
}

@MainActor
@Suite("Machine d'état temps réel", .serialized)
struct RealtimeStateMachineTests {
    /// Quand l'upgrade WebSocket est systématiquement refusé (proxy Cloudflare), la session ne doit
    /// **pas** rester bloquée sur « Reconnexion… » : elle bascule en repli REST (`restMode`), badge
    /// honnête, tout en continuant de peupler les statuts.
    @Test("Upgrade WS refusé → bascule en repli REST (pas de reconnexion infinie)", .timeLimit(.minutes(1)))
    func fallsBackToRESTModeWhenWebSocketRefused() async throws {
        WSRefusingURLProtocol.reset()
        defer { WSRefusingURLProtocol.reset() }
        WSRefusingURLProtocol.restResponses["/api/v1/printers/"] = (
            200,
            Data(#"[{"id":1,"name":"X2D","model":"X2D"}]"#.utf8)
        )
        WSRefusingURLProtocol.restResponses["/api/v1/printers/1/status"] = (
            200,
            Data(#"{"id":1,"name":"X2D","connected":true,"state":"RUNNING","progress":7}"#.utf8)
        )

        let environment = AppEnvironment.inMemory(session: stubSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Prof", baseURL: url)
        let center = ServerNotificationCenter(
            server: server,
            connectionFactory: environment.connectionFactory
        )

        center.start()
        defer { center.stop() }

        // Attend la bascule en repli REST (2 échecs d'upgrade), sans jamais rester en reconnexion.
        // Budget large (jusqu'à ~30 s, sous la `.timeLimit` d'une minute) : sur un runner CI chargé,
        // deux vrais handshakes WebSocket refusés + le back-off peuvent dépasser quelques secondes.
        var reachedRESTMode = false
        for _ in 0 ..< 600 {
            if center.realtimeState == .restMode {
                reachedRESTMode = true
                break
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        #expect(reachedRESTMode)
        #expect(center.realtimeState != .reconnecting)

        // Le repli REST a bien peuplé le statut vivant malgré l'absence de WebSocket.
        var status: PrinterStatus?
        for _ in 0 ..< 100 {
            if let live = center.status(for: 1) {
                status = live
                break
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
        let live = try #require(status)
        #expect(live.state == .running)
        #expect(live.connected == true)
    }
}
