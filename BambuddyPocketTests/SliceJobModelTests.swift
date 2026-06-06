// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// `URLProtocol` routant les trois endpoints de découpe par chemin : présets, soumission, et
/// interrogation du job. Le statut et le corps servis sont configurables par test.
private final class SliceStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var presets: (status: Int, body: Data) = (200, Data("{}".utf8))
    nonisolated(unsafe) static var sliceHandle: (status: Int, body: Data) = (202, Data("{}".utf8))
    /// File de réponses successives pour `GET /slice-jobs/{id}` (une par tick de poll).
    nonisolated(unsafe) static var jobResponses: [Data] = []
    nonisolated(unsafe) static var jobIndex = 0

    static func reset() {
        presets = (200, Data("{}".utf8))
        sliceHandle = (202, Data("{}".utf8))
        jobResponses = []
        jobIndex = 0
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let status: Int
        let body: Data
        if path.hasSuffix("/slicer/presets") {
            (status, body) = Self.presets
        } else if path.hasSuffix("/slice") {
            (status, body) = Self.sliceHandle
        } else if path.contains("/slice-jobs/") {
            let idx = min(Self.jobIndex, Self.jobResponses.count - 1)
            body = Self.jobResponses.isEmpty ? Data("{}".utf8) : Self.jobResponses[idx]
            Self.jobIndex += 1
            status = 200
        } else {
            status = 404
            body = Data()
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func sliceStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [SliceStubURLProtocol.self]
    return URLSession(configuration: config)
}

/// Tests des **transitions de phase** de `SliceJobModel` (B2). Aucune impression n'est lancée : le
/// flux s'arrête à l'ajout du fichier tranché en bibliothèque.
@MainActor
@Suite("Transitions du modèle de découpe", .serialized)
struct SliceJobModelTests {
    private func makeModel() throws -> SliceJobModel {
        let environment = AppEnvironment.inMemory(session: sliceStubSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Atelier", baseURL: url)
        return SliceJobModel(
            fileID: 7,
            fileName: "part.3mf",
            server: server,
            connectionFactory: environment.connectionFactory
        )
    }

    private func presetsJSON() -> Data {
        Data(#"""
        {"standard":{
          "printer":[{"id":"p1","name":"X1","source":"standard"}],
          "process":[{"id":"pr1","name":"0.20mm","source":"standard"}],
          "filament":[{"id":"f1","name":"PLA","source":"standard"}]
        },"cloud_status":"ok"}
        """#.utf8)
    }

    @Test("Des présets disponibles mènent à .ready avec présélection des premiers")
    func loadsPresetsToReady() async throws {
        SliceStubURLProtocol.reset()
        defer { SliceStubURLProtocol.reset() }
        SliceStubURLProtocol.presets = (200, presetsJSON())

        let model = try makeModel()
        await model.loadPresets()

        #expect(model.phase == .ready)
        #expect(model.selectedPrinter?.name == "X1")
        #expect(model.selectedProcess?.name == "0.20mm")
        #expect(model.selectedFilament?.name == "PLA")
        #expect(model.canSlice)
    }

    @Test("Des présets vides mènent à .failed (formulaire inutilisable)")
    func emptyPresetsFail() async throws {
        SliceStubURLProtocol.reset()
        defer { SliceStubURLProtocol.reset() }
        SliceStubURLProtocol.presets = (200, Data(#"{"cloud_status":"ok"}"#.utf8))

        let model = try makeModel()
        await model.loadPresets()

        if case .failed = model.phase {} else {
            Issue.record("attendu .failed, obtenu \(model.phase)")
        }
        #expect(!model.canSlice)
    }

    @Test("Un 503 du sidecar de découpe mène à .failed")
    func slicerUnavailableFails() async throws {
        SliceStubURLProtocol.reset()
        defer { SliceStubURLProtocol.reset() }
        SliceStubURLProtocol.presets = (503, Data("{}".utf8))

        let model = try makeModel()
        await model.loadPresets()

        if case .failed = model.phase {} else {
            Issue.record("attendu .failed, obtenu \(model.phase)")
        }
    }

    @Test("Une découpe qui aboutit mène à .completed avec le résultat")
    func sliceCompletes() async throws {
        SliceStubURLProtocol.reset()
        defer { SliceStubURLProtocol.reset() }
        SliceStubURLProtocol.presets = (200, presetsJSON())
        SliceStubURLProtocol.sliceHandle = (202, Data(#"{"job_id":42,"status":"pending"}"#.utf8))
        SliceStubURLProtocol.jobResponses = [
            Data(#"{"job_id":42,"status":"completed","result":{"name":"part.gcode.3mf"}}"#.utf8)
        ]

        let model = try makeModel()
        await model.loadPresets()
        await model.slice()

        if case let .completed(result) = model.phase {
            #expect(result.name == "part.gcode.3mf")
        } else {
            Issue.record("attendu .completed, obtenu \(model.phase)")
        }
    }

    @Test("Un job en échec mène à .failed avec le détail d'erreur")
    func sliceFails() async throws {
        SliceStubURLProtocol.reset()
        defer { SliceStubURLProtocol.reset() }
        SliceStubURLProtocol.presets = (200, presetsJSON())
        SliceStubURLProtocol.sliceHandle = (202, Data(#"{"job_id":43,"status":"pending"}"#.utf8))
        SliceStubURLProtocol.jobResponses = [
            Data(#"{"job_id":43,"status":"failed","error_detail":"bad geometry"}"#.utf8)
        ]

        let model = try makeModel()
        await model.loadPresets()
        await model.slice()

        if case let .failed(message) = model.phase {
            #expect(message == "bad geometry")
        } else {
            Issue.record("attendu .failed, obtenu \(model.phase)")
        }
    }
}
