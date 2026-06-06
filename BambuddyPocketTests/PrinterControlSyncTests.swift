// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// `URLProtocol` minimal pour mocker les réponses REST dans le test-cible app : réponses par chemin
/// (la query est ignorée), avec un compteur d'appels par chemin pour vérifier les re-fetch.
private final class ControlStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [String: (Int, Data)] = [:]
    nonisolated(unsafe) static var hits: [String: Int] = [:]

    static func reset() {
        responses = [:]
        hits = [:]
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
        Self.hits[path, default: 0] += 1
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

private func controlStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ControlStubURLProtocol.self]
    return URLSession(configuration: config)
}

/// Tests du correctif **P1** : après une action de contrôle, le statut est re-fetché et fusionné
/// (le toggle bouge), et un `409` est traité comme un no-op réussi (pas d'erreur affichée).
@MainActor
@Suite("Synchro du statut après une action de contrôle", .serialized)
struct PrinterControlSyncTests {
    private func makeModel(session: URLSession) throws -> PrinterListModel {
        let environment = AppEnvironment.inMemory(session: session)
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Prof", baseURL: url)
        let center = ServerNotificationCenter(server: server, connectionFactory: environment.connectionFactory)
        return PrinterListModel(
            server: server,
            connectionFactory: environment.connectionFactory,
            notificationCenter: center
        )
    }

    /// Allumer la lumière doit déclencher un re-fetch `GET /printers/{id}/status` dont l'état
    /// (lumière allumée) est fusionné → le toggle reflète l'état réel sans attendre le WebSocket.
    @Test("Après allumage, le statut est re-fetché et le toggle reflète l'état réel")
    func refreshesStatusAfterControl() async throws {
        ControlStubURLProtocol.reset()
        defer { ControlStubURLProtocol.reset() }
        ControlStubURLProtocol.responses["/api/v1/printers/1/chamber-light"] = (200, Data("{}".utf8))
        ControlStubURLProtocol.responses["/api/v1/printers/1/status"] = (
            200,
            Data(#"{"id":1,"name":"X2D","connected":true,"chamber_light":true}"#.utf8)
        )

        let model = try makeModel(session: controlStubSession())
        let printer = Printer(id: 1, name: "X2D", model: "X2D")

        #expect(model.status(for: printer)?.chamberLight == nil)
        await model.setChamberLight(printer, on: true)

        #expect(model.controlError == nil)
        #expect(model.status(for: printer)?.chamberLight == true)
        #expect(ControlStubURLProtocol.hits["/api/v1/printers/1/status"] == 1)
    }

    /// Un `409` (« déjà dans l'état désiré ») ne doit **pas** afficher d'erreur, et le statut est
    /// quand même re-fetché pour resynchroniser le toggle.
    @Test("Un 409 est traité comme un no-op réussi et resynchronise le statut")
    func conflictIsTreatedAsNoOp() async throws {
        ControlStubURLProtocol.reset()
        defer { ControlStubURLProtocol.reset() }
        ControlStubURLProtocol.responses["/api/v1/printers/1/drying/start"] = (
            409,
            Data(#"{"detail":"AMS is already drying"}"#.utf8)
        )
        ControlStubURLProtocol.responses["/api/v1/printers/1/status"] = (
            200,
            Data(#"{"id":1,"name":"X2D","connected":true}"#.utf8)
        )

        let model = try makeModel(session: controlStubSession())
        let printer = Printer(id: 1, name: "X2D", model: "X2D")

        await model.startDrying(printer, amsID: 0)

        #expect(model.controlError == nil)
        #expect(ControlStubURLProtocol.hits["/api/v1/printers/1/status"] == 1)
    }

    /// L'état « action en vol » (retour device A1) est posé pendant la commande puis **toujours
    /// retiré** à la fin — succès comme erreur — pour que la roue/désactivation disparaisse.
    @Test("L'état « en vol » est posé puis retiré après l'action (succès et erreur)")
    func inFlightStateIsClearedAfterAction() async throws {
        ControlStubURLProtocol.reset()
        defer { ControlStubURLProtocol.reset() }
        ControlStubURLProtocol.responses["/api/v1/printers/1/chamber-light"] = (200, Data("{}".utf8))
        ControlStubURLProtocol.responses["/api/v1/printers/1/print/pause"] = (500, Data("{}".utf8))
        ControlStubURLProtocol.responses["/api/v1/printers/1/status"] = (
            200,
            Data(#"{"id":1,"name":"X2D","connected":true}"#.utf8)
        )

        let model = try makeModel(session: controlStubSession())
        let printer = Printer(id: 1, name: "X2D", model: "X2D")

        #expect(model.isRunning(.light, for: printer) == false)
        #expect(model.hasRunningAction(for: printer.id) == false)

        // Succès : l'état est retiré après le re-fetch de confirmation.
        await model.setChamberLight(printer, on: true)
        #expect(model.isRunning(.light, for: printer) == false)
        #expect(model.hasRunningAction(for: printer.id) == false)

        // Erreur serveur : l'état est tout de même retiré (le `defer` s'exécute).
        await model.pause(printer)
        #expect(model.isRunning(.pauseResume, for: printer) == false)
        #expect(model.hasRunningAction(for: printer.id) == false)
    }

    /// Une vraie erreur serveur (500) reste une erreur affichée, mais le statut est tout de même
    /// re-fetché (on resynchronise quoi qu'il arrive).
    @Test("Une erreur 500 reste affichée mais resynchronise quand même le statut")
    func realErrorStillSurfaces() async throws {
        ControlStubURLProtocol.reset()
        defer { ControlStubURLProtocol.reset() }
        ControlStubURLProtocol.responses["/api/v1/printers/1/chamber-light"] = (500, Data("{}".utf8))
        ControlStubURLProtocol.responses["/api/v1/printers/1/status"] = (
            200,
            Data(#"{"id":1,"name":"X2D","connected":true}"#.utf8)
        )

        let model = try makeModel(session: controlStubSession())
        let printer = Printer(id: 1, name: "X2D", model: "X2D")

        await model.setChamberLight(printer, on: true)

        #expect(model.controlError != nil)
        #expect(ControlStubURLProtocol.hits["/api/v1/printers/1/status"] == 1)
    }
}
