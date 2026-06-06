// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// `URLProtocol` qui enregistre la dernière requête (méthode, chemin, corps) et renvoie un JSON
/// configurable, pour vérifier le contrat des appels « archives de projet ».
private final class ProjectArchivesStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responseBody = Data("[]".utf8)
    nonisolated(unsafe) static var lastMethod: String?
    nonisolated(unsafe) static var lastPath: String?
    nonisolated(unsafe) static var lastBody: Data?

    static func reset() {
        responseBody = Data("[]".utf8)
        lastMethod = nil
        lastPath = nil
        lastBody = nil
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    /// Lit le corps de la requête, qu'il soit fourni en `httpBody` ou converti en flux par `URLProtocol`.
    private static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let size = 4096
        var buffer = [UInt8](repeating: 0, count: size)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: size)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }

    override func startLoading() {
        Self.lastMethod = request.httpMethod
        Self.lastPath = request.url?.path
        Self.lastBody = Self.body(of: request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func projectStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [ProjectArchivesStubURLProtocol.self]
    return URLSession(configuration: config)
}

/// Tests du contrat « archives d'un projet » (add/remove-archives, list).
@MainActor
@Suite("Archives d'un projet", .serialized)
struct ProjectArchivesModelTests {
    private func makeModel(session: URLSession) throws -> ProjectListModel {
        let environment = AppEnvironment.inMemory(session: session)
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Atelier", baseURL: url)
        return ProjectListModel(server: server, connectionFactory: environment.connectionFactory)
    }

    private func project(id: Int) -> Project {
        Project(id: id, name: "Lampe", status: "active")
    }

    @Test("addArchivesToProject encode {\"archive_ids\":[…]} vers POST /add-archives")
    func addArchivesEncodesBody() async throws {
        ProjectArchivesStubURLProtocol.reset()
        defer { ProjectArchivesStubURLProtocol.reset() }
        let environment = AppEnvironment.inMemory(session: projectStubSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Atelier", baseURL: url)
        let client = try environment.connectionFactory.makeClient(for: server)

        try await client.addArchivesToProject(projectID: 7, archiveIDs: [3, 9])

        #expect(ProjectArchivesStubURLProtocol.lastMethod == "POST")
        #expect(ProjectArchivesStubURLProtocol.lastPath == "/api/v1/projects/7/add-archives")
        let body = try #require(ProjectArchivesStubURLProtocol.lastBody)
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let ids = try #require(decoded?["archive_ids"] as? [Int])
        #expect(ids == [3, 9])
    }

    @Test("removeArchive POST /projects/{id}/remove-archives")
    func removeArchivePostsBatch() async throws {
        ProjectArchivesStubURLProtocol.reset()
        defer { ProjectArchivesStubURLProtocol.reset() }
        let environment = AppEnvironment.inMemory(session: projectStubSession())
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Atelier", baseURL: url)
        let client = try environment.connectionFactory.makeClient(for: server)

        try await client.removeArchivesFromProject(projectID: 4, archiveIDs: [11])

        #expect(ProjectArchivesStubURLProtocol.lastMethod == "POST")
        #expect(ProjectArchivesStubURLProtocol.lastPath == "/api/v1/projects/4/remove-archives")
        let body = try #require(ProjectArchivesStubURLProtocol.lastBody)
        let decoded = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let ids = try #require(decoded?["archive_ids"] as? [Int])
        #expect(ids == [11])
    }

    @Test("projectArchives décode la liste d'archives rattachées")
    func projectArchivesDecodesList() async throws {
        ProjectArchivesStubURLProtocol.reset()
        defer { ProjectArchivesStubURLProtocol.reset() }
        ProjectArchivesStubURLProtocol.responseBody = Data(
            #"[{"id":1,"status":"completed"},{"id":2,"status":"failed"}]"#.utf8
        )

        let model = try makeModel(session: projectStubSession())
        let archives = await model.projectArchives(for: project(id: 5))

        #expect(ProjectArchivesStubURLProtocol.lastMethod == "GET")
        #expect(ProjectArchivesStubURLProtocol.lastPath == "/api/v1/projects/5/archives")
        #expect(archives?.map(\.id) == [1, 2])
    }
}
