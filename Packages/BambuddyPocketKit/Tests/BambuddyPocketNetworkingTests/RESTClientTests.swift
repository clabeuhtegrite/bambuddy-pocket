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

    @Test("searchArchives encode la requête sur /archives/search?q=")
    func searchesArchives() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"[{"id":1,"status":"completed","print_name":"Test Cube"}]"#)
        let client = try makeClient()
        let results = try await client.searchArchives("Cube box")
        #expect(results.first?.printName == "Test Cube")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/archives/search?q=Cube%20box")
    }

    @Test("searchArchives renvoie [] pour une requête trop courte (sans appel réseau)")
    func searchArchivesShortQuery() async throws {
        MockURLProtocol.reset()
        let client = try makeClient()
        let results = try await client.searchArchives("a")
        #expect(results.isEmpty)
        #expect(MockURLProtocol.lastRequest == nil)
    }

    @Test("updateArchive PATCH /archives/{id} et omet les champs nil")
    func updatesArchive() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":1,"status":"completed","tags":"a,b","notes":"hi"}"#)
        let client = try makeClient()
        let updated = try await client.updateArchive(id: 1, ArchiveUpdate(tags: "a,b", notes: "hi"))
        #expect(updated.tagList == ["a", "b"])
        #expect(updated.notes == "hi")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/archives/1")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["tags"] as? String == "a,b")
        #expect(json.keys.contains("cost") == false)
    }

    @Test("toggleArchiveFavorite poste sur /archives/{id}/favorite et décode")
    func togglesArchiveFavorite() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":1,"status":"completed","is_favorite":true}"#)
        let client = try makeClient()
        let archive = try await client.toggleArchiveFavorite(id: 1)
        #expect(archive.isFavorite == true)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/archives/1/favorite")
    }

    @Test("deleteArchive envoie DELETE /archives/{id}")
    func deletesArchive() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.deleteArchive(id: 7)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/archives/7")
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

    @Test("cameraStatus cible /camera/status et décode")
    func fetchesCameraStatus() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"active":true,"has_frames":true,"seconds_since_frame":0.5,"stream_uptime":30,"stalled":false}"#
        )
        let client = try makeClient()
        let status = try await client.cameraStatus(printerID: 2)
        #expect(status.active == true)
        #expect(status.hasFrames == true)
        #expect(status.stalled == false)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/2/camera/status")
    }

    @Test("checkPlate cible /camera/check-plate et décode")
    func checksPlate() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"is_empty":true,"confidence":0.92,"difference_percent":1.2,"#
                + #""message":"Plate looks empty","needs_calibration":false,"light_warning":false}"#
        )
        let client = try makeClient()
        let result = try await client.checkPlate(printerID: 3)
        #expect(result.isEmpty == true)
        #expect(result.confidencePercent == 92)
        #expect(result.needsCalibration == false)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/3/camera/check-plate")
    }

    @Test("cameraStreamToken poste sur /printers/camera/stream-token et décode")
    func createsStreamToken() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"token":"abc123"}"#)
        let client = try makeClient()
        let token = try await client.cameraStreamToken()
        #expect(token.token == "abc123")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/camera/stream-token")
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

    @Test("archiveStats cible /archives/stats et décode")
    func fetchesArchiveStats() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"""
            {"total_prints":10,"successful_prints":8,"failed_prints":2,"total_print_time_hours":5.5,
             "total_filament_grams":120,"total_cost":3.2,"prints_by_filament_type":{},"prints_by_printer":{}}
            """#
        )
        let client = try makeClient()
        let stats = try await client.archiveStats()
        #expect(stats.totalPrints == 10)
        #expect(stats.successfulPrints == 8)
        #expect(stats.totalCost == 3.2)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/archives/stats")
    }

    @Test("addToQueue poste sur /queue/")
    func addsToQueue() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.addToQueue(QueueItemCreate(archiveId: 7))
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/queue/")
    }

    @Test("inventorySpools cible /inventory/spools et décode")
    func listsSpools() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"[{"id":4,"material":"PLA","label_weight":1000,"weight_used":100}]"#)
        let client = try makeClient()
        let spools = try await client.inventorySpools()
        #expect(spools.map(\.id) == [4])
        #expect(spools.first?.remainingGrams == 900)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/inventory/spools")
    }

    @Test("spool(id:) cible /inventory/spools/{id} et décode")
    func fetchesSpool() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":4,"material":"PLA","brand":"Bambu","label_weight":1000,"weight_used":150}"#)
        let client = try makeClient()
        let spool = try await client.spool(id: 4)
        #expect(spool.id == 4)
        #expect(spool.remainingGrams == 850)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/inventory/spools/4")
    }

    @Test("updateSpool PATCH /inventory/spools/{id} et omet les champs nil")
    func updatesSpool() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":4,"material":"PLA","note":"sèche","storage_location":"A"}"#)
        let client = try makeClient()
        let updated = try await client.updateSpool(id: 4, SpoolUpdate(storageLocation: "A", note: "sèche"))
        #expect(updated.note == "sèche")
        #expect(updated.storageLocation == "A")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/inventory/spools/4")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["storage_location"] as? String == "A")
        #expect(json.keys.contains("material") == false)
    }

    @Test("spoolUsage cible /inventory/spools/{id}/usage et décode")
    func fetchesSpoolUsage() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"id":2,"spool_id":4,"weight_used":12.5,"percent_used":3,"status":"completed","#
                + #""print_name":"Cube","created_at":"2026-06-01T10:00:00Z"}]"#
        )
        let client = try makeClient()
        let usage = try await client.spoolUsage(id: 4)
        #expect(usage.first?.weightUsed == 12.5)
        #expect(usage.first?.printName == "Cube")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/inventory/spools/4/usage")
    }

    @Test("resetSpoolUsage et deleteSpool ciblent les bons chemins")
    func resetsAndDeletesSpool() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":4,"material":"PLA"}"#)
        let client = try makeClient()
        _ = try await client.resetSpoolUsage(id: 4)
        #expect(try #require(MockURLProtocol.lastRequest).url?.absoluteString
            == "https://host.example.com/api/v1/inventory/spools/4/reset-usage")
        #expect(try #require(MockURLProtocol.lastRequest).httpMethod == "POST")
        try await client.deleteSpool(id: 4)
        #expect(try #require(MockURLProtocol.lastRequest).httpMethod == "DELETE")
        #expect(try #require(MockURLProtocol.lastRequest).url?.absoluteString
            == "https://host.example.com/api/v1/inventory/spools/4")
    }

    @Test("libraryFiles cible /library/files/ et décode")
    func listsLibrary() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"id":2,"filename":"benchy.3mf","file_type":"3mf","file_size":1024,"print_count":3}]"#
        )
        let client = try makeClient()
        let files = try await client.libraryFiles()
        #expect(files.map(\.id) == [2])
        #expect(files.first?.filename == "benchy.3mf")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/library/files/")
    }

    @Test("libraryFile(id:) cible /library/files/{id} et décode")
    func fetchesLibraryFile() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"id":2,"filename":"gear.gcode.3mf","file_type":"3mf","file_size":4096,"notes":"hi"}"#
        )
        let client = try makeClient()
        let file = try await client.libraryFile(id: 2)
        #expect(file.notes == "hi")
        #expect(file.isSliced == true)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/library/files/2")
    }

    @Test("updateLibraryFile PUT /library/files/{id} et omet les champs nil")
    func updatesLibraryFile() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":2,"filename":"gear_v2.gcode.3mf","file_type":"3mf","notes":"calibré"}"#)
        let client = try makeClient()
        let updated = try await client.updateLibraryFile(
            id: 2,
            LibraryFileUpdate(filename: "gear_v2.gcode.3mf", notes: "calibré")
        )
        #expect(updated.filename == "gear_v2.gcode.3mf")
        #expect(updated.notes == "calibré")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "PUT")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/library/files/2")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["notes"] as? String == "calibré")
        #expect(json.keys.contains("folder_id") == false)
    }

    @Test("deleteLibraryFile envoie DELETE /library/files/{id}")
    func deletesLibraryFile() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"status":"success"}"#)
        let client = try makeClient()
        try await client.deleteLibraryFile(id: 2)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/library/files/2")
    }

    @Test("projects cible /projects/ et décode (description → details)")
    func listsProjects() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"id":1,"name":"Gridfinity","status":"active","description":"Bins","progress_percent":50}]"#
        )
        let client = try makeClient()
        let projects = try await client.projects()
        #expect(projects.first?.name == "Gridfinity")
        #expect(projects.first?.details == "Bins")
        #expect(projects.first?.progressFraction == 0.5)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/projects/")
    }

    @Test("project(id:) cible /projects/{id} et décode")
    func fetchesProject() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":1,"name":"Gridfinity","status":"active","description":"Bins","notes":"n"}"#)
        let client = try makeClient()
        let project = try await client.project(id: 1)
        #expect(project.name == "Gridfinity")
        #expect(project.details == "Bins")
        #expect(project.notes == "n")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/projects/1")
    }

    @Test("createProject poste sur /projects/ et décode")
    func createsProject() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":3,"name":"New","status":"active","target_count":5}"#)
        let client = try makeClient()
        let created = try await client.createProject(ProjectCreate(name: "New", targetCount: 5, priority: "high"))
        #expect(created.id == 3)
        #expect(created.targetCount == 5)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/projects/")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["name"] as? String == "New")
        #expect(json["priority"] as? String == "high")
    }

    @Test("updateProject PATCH /projects/{id} et omet les champs nil")
    func updatesProject() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":1,"name":"Gridfinity","status":"completed","notes":"fini"}"#)
        let client = try makeClient()
        let updated = try await client.updateProject(id: 1, ProjectUpdate(status: "completed", notes: "fini"))
        #expect(updated.status == "completed")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/projects/1")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["status"] as? String == "completed")
        #expect(json.keys.contains("name") == false)
    }

    @Test("deleteProject envoie DELETE /projects/{id}")
    func deletesProject() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.deleteProject(id: 5)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/projects/5")
    }

    @Test("createPrinter poste sur /printers/ et décode la réponse")
    func createsPrinter() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":1,"name":"X1C"}"#)
        let client = try makeClient()
        let create = PrinterCreate(name: "X1C", serialNumber: "SER", ipAddress: "1.2.3.4", accessCode: "0000")
        let created = try await client.createPrinter(create)
        #expect(created.id == 1)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/")
    }

    @Test("deleteQueueItem envoie DELETE /queue/{id}")
    func deletesQueueItem() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.deleteQueueItem(id: 8)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/queue/8")
    }

    @Test("stopQueueItem poste sur /queue/{id}/stop")
    func stopsQueueItem() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.stopQueueItem(id: 6)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/queue/6/stop")
    }

    @Test("updateQueueItem PATCH /queue/{id} et omet les champs nil")
    func updatesQueueItem() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"id":2,"position":1,"status":"pending","manual_start":true,"#
                + #""scheduled_time":"2026-06-10T08:00:00+00:00Z"}"#
        )
        let client = try makeClient()
        let updated = try await client.updateQueueItem(
            id: 2,
            QueueItemUpdate(scheduledTime: "2026-06-10T08:00:00Z", manualStart: true)
        )
        #expect(updated.manualStart == true)
        #expect(updated.scheduledTime == "2026-06-10T08:00:00+00:00Z")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/queue/2")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["manual_start"] as? Bool == true)
        #expect(json["scheduled_time"] as? String == "2026-06-10T08:00:00Z")
        // Les champs non renseignés ne doivent PAS être encodés (sinon le serveur les remet à null).
        #expect(json["printer_id"] == nil)
        #expect(json.keys.contains("printer_id") == false)
    }

    @Test("bulkUpdateQueue PATCH /queue/bulk et décode la réponse")
    func bulkUpdatesQueue() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"updated_count":2,"skipped_count":1,"message":"Updated 2 items"}"#)
        let client = try makeClient()
        let response = try await client.bulkUpdateQueue(QueueBulkUpdate(itemIds: [2, 3], manualStart: true))
        #expect(response.updatedCount == 2)
        #expect(response.skippedCount == 1)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/queue/bulk")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["item_ids"] as? [Int] == [2, 3])
    }

    @Test("queueBatches cible /queue/batches et décode les compteurs")
    func listsBatches() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"id":1,"name":"Cube ×3","quantity":3,"status":"active","pending_count":2,"#
                + #""printing_count":0,"completed_count":1,"failed_count":0,"cancelled_count":0}]"#
        )
        let client = try makeClient()
        let batches = try await client.queueBatches()
        #expect(batches.first?.name == "Cube ×3")
        #expect(batches.first?.pendingCount == 2)
        #expect(batches.first?.resolvedCount == 1)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/queue/batches")
    }

    @Test("cancelQueueBatch envoie DELETE /queue/batches/{id}")
    func cancelsBatch() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.cancelQueueBatch(id: 1)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/queue/batches/1")
    }

    @Test("startDrying poste avec ?ams_id=1")
    func startsDrying() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.startDrying(id: 5, amsID: 1)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/5/drying/start?ams_id=1")
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

    @Test("clearPlate poste sur /printers/{id}/clear-plate")
    func clearsPlate() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.clearPlate(id: 7)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/7/clear-plate")
    }

    @Test("homeAxes poste sur /printers/{id}/home-axes")
    func homesAxes() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.homeAxes(id: 4)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/4/home-axes")
    }

    @Test("connectPrinter et disconnectPrinter ciblent les bons chemins")
    func connectsAndDisconnects() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.connectPrinter(id: 2)
        #expect(try #require(MockURLProtocol.lastRequest).url?.path == "/api/v1/printers/2/connect")
        try await client.disconnectPrinter(id: 2)
        #expect(try #require(MockURLProtocol.lastRequest).url?.path == "/api/v1/printers/2/disconnect")
    }

    @Test("calibrate encode les drapeaux en paramètres de requête")
    func calibratesWithFlags() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.calibrate(id: 1, options: CalibrationOptions(bedLeveling: true, vibration: true))
        let request = try #require(MockURLProtocol.lastRequest)
        let url = try #require(request.url?.absoluteString)
        #expect(url.contains("/printers/1/calibration?"))
        #expect(url.contains("bed_leveling=true"))
        #expect(url.contains("vibration=true"))
        #expect(url.contains("motor_noise=false"))
    }

    @Test("printObjects cible /print/objects et décode")
    func fetchesPrintObjects() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"objects":[{"id":1,"name":"A","x":1,"y":2,"skipped":false}],"#
                + #""total":1,"skipped_count":0,"is_printing":true}"#
        )
        let client = try makeClient()
        let objects = try await client.printObjects(id: 3)
        #expect(objects.total == 1)
        #expect(objects.objects.first?.name == "A")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/3/print/objects")
    }

    @Test("skipObjects poste un tableau d'identifiants")
    func skipsObjects() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.skipObjects(id: 5, objectIDs: [1, 3])
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/5/print/skip-objects")
        let body = try #require(MockURLProtocol.lastBody)
        let decoded = try JSONDecoder().decode([Int].self, from: body)
        #expect(decoded == [1, 3])
    }

    @Test("amsLoad et amsResetTray ciblent les bons chemins")
    func loadsAndResetsAMS() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.amsLoad(id: 1, trayID: 2)
        #expect(try #require(MockURLProtocol.lastRequest).url?.absoluteString
            == "https://host.example.com/api/v1/printers/1/ams/load?tray_id=2")
        try await client.amsResetTray(id: 1, amsID: 0, trayID: 2)
        #expect(try #require(MockURLProtocol.lastRequest).url?.absoluteString
            == "https://host.example.com/api/v1/printers/1/ams/0/tray/2/reset")
    }

    @Test("deletePrinter envoie DELETE /printers/{id}")
    func deletesPrinter() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.deletePrinter(id: 9)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/printers/9")
    }

    @Test("settings cible /settings/ et décode (langue, devise, imprimante par défaut)")
    func fetchesSettings() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"language":"fr","currency":"EUR","default_printer_id":2,"#
                + #""default_filament_cost":25.0,"energy_cost_per_kwh":0.15,"notification_language":"en"}"#
        )
        let client = try makeClient()
        let settings = try await client.settings()
        #expect(settings.language == "fr")
        #expect(settings.currency == "EUR")
        #expect(settings.defaultPrinterID == 2)
        #expect(settings.energyCostPerKwh == 0.15)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/settings/")
    }

    @Test("settings tolère default_printer_id nul")
    func fetchesSettingsWithNullDefaultPrinter() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"language":"en","currency":"USD","default_printer_id":null}"#)
        let client = try makeClient()
        let settings = try await client.settings()
        #expect(settings.defaultPrinterID == nil)
        #expect(settings.currency == "USD")
    }

    @Test("updateSettings PATCH /settings/ et omet les champs nil")
    func updatesSettings() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"language":"de","currency":"USD"}"#)
        let client = try makeClient()
        let updated = try await client.updateSettings(AppSettingsUpdate(language: "de"))
        #expect(updated.language == "de")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/settings/")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["language"] as? String == "de")
        #expect(json.keys.contains("currency") == false)
    }

    @Test("updateSettings encode default_printer_id quand fourni")
    func updatesSettingsDefaultPrinter() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"default_printer_id":3}"#)
        let client = try makeClient()
        _ = try await client.updateSettings(AppSettingsUpdate(defaultPrinterID: 3))
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["default_printer_id"] as? Int == 3)
        #expect(json.keys.contains("language") == false)
    }

    @Test("systemInfo cible /system/info et décode les sous-objets")
    func fetchesSystemInfo() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"app":{"version":"0.2.4.4"},"#
                + #""system":{"platform":"Linux","architecture":"aarch64","uptime_formatted":"1d 7h"},"#
                + #""memory":{"total_formatted":"7.7 GB","percent_used":10.5},"#
                + #""cpu":{"count":8,"percent":0.0},"#
                + #""storage":{"disk_total_formatted":"223.6 GB","disk_percent_used":3.4},"#
                + #""database":{"engine":"SQLite","archives":1,"projects":2,"total_filament_kg":0.01}}"#
        )
        let client = try makeClient()
        let info = try await client.systemInfo()
        #expect(info.app?.version == "0.2.4.4")
        #expect(info.system?.architecture == "aarch64")
        #expect(info.memory?.percentUsed == 10.5)
        #expect(info.cpu?.count == 8)
        #expect(info.storage?.diskPercentUsed == 3.4)
        #expect(info.database?.projects == 2)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/system/info")
    }

    @Test("systemHealth cible /system/health et résume les problèmes")
    func fetchesSystemHealth() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"scanned_entries":4000,"log_available":true,"#
                + #""summary":{"total":2,"bug":1,"environment":1,"layer8":0}}"#
        )
        let client = try makeClient()
        let health = try await client.systemHealth()
        #expect(health.logAvailable == true)
        #expect(health.scannedEntries == 4000)
        #expect(health.hasFindings)
        #expect(health.summary?.bug == 1)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/system/health")
    }

    @Test("systemHealth sans problème -> hasFindings == false")
    func systemHealthWithoutFindings() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"log_available":true,"summary":{"total":0}}"#)
        let client = try makeClient()
        let health = try await client.systemHealth()
        #expect(health.hasFindings == false)
    }

    @Test("apiKeys cible /api-keys/ et décode (sans secret complet)")
    func listsAPIKeys() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"id":1,"name":"probe","key_prefix":"bb__m-Vr...","can_control_printer":false,"#
                + #""can_queue":true,"enabled":true,"created_at":"2026-06-04T07:38:11"}]"#
        )
        let client = try makeClient()
        let keys = try await client.apiKeys()
        #expect(keys.first?.name == "probe")
        #expect(keys.first?.keyPrefix == "bb__m-Vr...")
        #expect(keys.first?.secret == nil)
        #expect(keys.first?.isEnabled == true)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/api-keys/")
    }

    @Test("createAPIKey POST /api-keys/ et expose le secret complet une fois")
    func createsAPIKey() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"id":2,"name":"mobile","key_prefix":"bb_kCXcD...","#
                + #""key":"bb_kCXcD_fullsecretvalue","can_control_printer":true,"enabled":true}"#
        )
        let client = try makeClient()
        let created = try await client.createAPIKey(APIKeyCreate(name: "mobile", canControlPrinter: true))
        #expect(created.id == 2)
        #expect(created.secret == "bb_kCXcD_fullsecretvalue")
        #expect(created.canControlPrinter == true)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["name"] as? String == "mobile")
        #expect(json["can_control_printer"] as? Bool == true)
    }

    @Test("updateAPIKey PATCH /api-keys/{id} pour révoquer (enabled=false) et omet les nil")
    func revokesAPIKey() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":2,"name":"mobile","enabled":false}"#)
        let client = try makeClient()
        let updated = try await client.updateAPIKey(id: 2, APIKeyUpdate(enabled: false))
        #expect(updated.isEnabled == false)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/api-keys/2")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["enabled"] as? Bool == false)
        #expect(json.keys.contains("name") == false)
    }

    @Test("deleteAPIKey envoie DELETE /api-keys/{id}")
    func deletesAPIKey() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.deleteAPIKey(id: 5)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/api-keys/5")
    }

    @Test("currentUser cible /auth/me et décode le profil enrichi")
    func fetchesCurrentUser() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"id":1,"username":"admin","role":"admin","is_admin":true,"auth_source":"local","#
                + #""groups":[{"id":1,"name":"Administrators"}]}"#
        )
        let client = try makeClient()
        let user = try await client.currentUser()
        #expect(user.username == "admin")
        #expect(user.authSource == "local")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/auth/me")
    }

    @Test("twoFactorStatus cible /auth/2fa/status et décode")
    func fetchesTwoFactorStatus() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"totp_enabled":true,"email_otp_enabled":false,"backup_codes_remaining":8}"#)
        let client = try makeClient()
        let status = try await client.twoFactorStatus()
        #expect(status.isEnabled)
        #expect(status.backupCodesRemaining == 8)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/auth/2fa/status")
    }

    @Test("logout poste sur /auth/logout")
    func postsLogout() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.logout()
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/auth/logout")
    }

    @Test("smartPlugs cible /smart-plugs/ et décode")
    func listsSmartPlugs() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"id":1,"name":"Bench plug","plug_type":"rest","enabled":true,"#
                + #""printer_id":2,"last_state":"off"}]"#
        )
        let client = try makeClient()
        let plugs = try await client.smartPlugs()
        #expect(plugs.first?.name == "Bench plug")
        #expect(plugs.first?.plugType == "rest")
        #expect(plugs.first?.printerID == 2)
        #expect(plugs.first?.isEnabled == true)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/smart-plugs/")
    }

    @Test("smartPlugStatus décode l'état, la joignabilité et la consommation")
    func fetchesSmartPlugStatus() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"state":"on","reachable":true,"device_name":"Plug-A","#
                + #""energy":{"power":42.5,"voltage":230.0,"today":0.12}}"#
        )
        let client = try makeClient()
        let status = try await client.smartPlugStatus(id: 1)
        #expect(status.isReachable)
        #expect(status.isOn == true)
        #expect(status.energy?.power == 42.5)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/smart-plugs/1/status")
    }

    @Test("controlSmartPlug poste l'action sur /smart-plugs/{id}/control")
    func controlsSmartPlug() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "{}")
        let client = try makeClient()
        try await client.controlSmartPlug(id: 3, action: .on)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/smart-plugs/3/control")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["action"] as? String == "on")
    }

    @Test("maintenanceOverview cible /maintenance/overview et décode les items")
    func fetchesMaintenanceOverview() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"printer_id":1,"printer_name":"VP-Test","printer_model":"X1C","total_print_hours":12.0,"#
                + #""maintenance_items":[{"id":1,"maintenance_type_name":"Clean Nozzle","interval_hours":100.0,"#
                + #""hours_until_due":-5.0,"is_due":true,"is_warning":false}]}]"#
        )
        let client = try makeClient()
        let overview = try await client.maintenanceOverview()
        #expect(overview.first?.printerName == "VP-Test")
        #expect(overview.first?.maintenanceItems?.first?.maintenanceTypeName == "Clean Nozzle")
        #expect(overview.first?.dueItems.count == 1)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/maintenance/overview")
    }

    @Test("discoveryStatus et discoveryInfo ciblent les bons chemins")
    func fetchesDiscovery() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"running":true}"#)
        let client = try makeClient()
        let status = try await client.discoveryStatus()
        #expect(status.isRunning)
        #expect(try #require(MockURLProtocol.lastRequest).url?.absoluteString
            == "https://host.example.com/api/v1/discovery/status")

        respond(
            status: 200,
            json: #"{"is_docker":true,"ssdp_running":false,"scan_running":false,"subnets":["172.18.0.0/16"]}"#
        )
        let info = try await client.discoveryInfo()
        #expect(info.isDocker == true)
        #expect(info.subnets == ["172.18.0.0/16"])
    }

    @Test("discoveredPrinters cible /discovery/printers et décode")
    func fetchesDiscoveredPrinters() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"serial":"01ABC","name":"X1C","ip_address":"192.168.1.50","model":"X1C"}]"#
        )
        let client = try makeClient()
        let printers = try await client.discoveredPrinters()
        #expect(printers.first?.name == "X1C")
        #expect(printers.first?.id == "01ABC")
        #expect(try #require(MockURLProtocol.lastRequest).url?.absoluteString
            == "https://host.example.com/api/v1/discovery/printers")
    }

    @Test("startDiscovery et stopDiscovery postent sur les bons chemins")
    func startsAndStopsDiscovery() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"running":true}"#)
        let client = try makeClient()
        let started = try await client.startDiscovery()
        #expect(started.isRunning)
        #expect(try #require(MockURLProtocol.lastRequest).httpMethod == "POST")
        #expect(try #require(MockURLProtocol.lastRequest).url?.absoluteString
            == "https://host.example.com/api/v1/discovery/start")
        respond(status: 200, json: #"{"running":false}"#)
        let stopped = try await client.stopDiscovery()
        #expect(stopped.isRunning == false)
        #expect(try #require(MockURLProtocol.lastRequest).url?.absoluteString
            == "https://host.example.com/api/v1/discovery/stop")
    }

    @Test("backupStatus cible /local-backup/status et décode")
    func fetchesBackupStatus() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"is_running":false,"enabled":true,"schedule":"daily","time":"03:00","#
                + #""retention":5,"last_backup_at":"2026-06-04T09:09:01Z","last_status":"success"}"#
        )
        let client = try makeClient()
        let status = try await client.backupStatus()
        #expect(status.isScheduleEnabled)
        #expect(status.schedule == "daily")
        #expect(status.retention == 5)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/local-backup/status")
    }

    @Test("backups cible /local-backup/backups et formate la taille")
    func listsBackups() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"filename":"bambuddy-backup-20260604.zip","size":39551,"#
                + #""created_at":"2026-06-04T09:09:01Z"}]"#
        )
        let client = try makeClient()
        let backups = try await client.backups()
        #expect(backups.first?.filename == "bambuddy-backup-20260604.zip")
        #expect(backups.first?.formattedSize != nil)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/local-backup/backups")
    }

    @Test("runBackup poste sur /local-backup/run et décode le résultat")
    func runsBackup() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"success":true,"message":"Backup created","filename":"bambuddy-backup-20260604.zip"}"#
        )
        let client = try makeClient()
        let result = try await client.runBackup()
        #expect(result.success == true)
        #expect(result.filename == "bambuddy-backup-20260604.zip")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/local-backup/run")
    }

    @Test("externalLinks cible /external-links/ et décode")
    func listsExternalLinks() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"id":1,"name":"Wiki","url":"https://wiki.example.com","icon":"link","sort_order":0}]"#
        )
        let client = try makeClient()
        let links = try await client.externalLinks()
        #expect(links.first?.name == "Wiki")
        #expect(links.first?.resolvedURL?.host == "wiki.example.com")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/external-links/")
    }

    @Test("createExternalLink POST /external-links/ et deleteExternalLink DELETE")
    func createsAndDeletesExternalLink() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"id":2,"name":"Docs","url":"https://docs.example.com"}"#)
        let client = try makeClient()
        let created = try await client.createExternalLink(
            ExternalLinkCreate(name: "Docs", url: "https://docs.example.com")
        )
        #expect(created.id == 2)
        let createRequest = try #require(MockURLProtocol.lastRequest)
        #expect(createRequest.httpMethod == "POST")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["name"] as? String == "Docs")
        #expect(json["url"] as? String == "https://docs.example.com")
        try await client.deleteExternalLink(id: 2)
        let deleteRequest = try #require(MockURLProtocol.lastRequest)
        #expect(deleteRequest.httpMethod == "DELETE")
        #expect(deleteRequest.url?.absoluteString == "https://host.example.com/api/v1/external-links/2")
    }

    @Test("filamentCatalog cible /filament-catalog/ et décode")
    func fetchesFilamentCatalog() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"id":9,"name":"Bambu ABS","type":"ABS","brand":"Bambu Lab","cost_per_kg":30.0,"#
                + #""currency":"USD","print_temp_min":260,"print_temp_max":280,"bed_temp_min":90,"bed_temp_max":100}]"#
        )
        let client = try makeClient()
        let catalog = try await client.filamentCatalog()
        #expect(catalog.first?.name == "Bambu ABS")
        #expect(catalog.first?.brand == "Bambu Lab")
        #expect(catalog.first?.nozzleTempRange == "260–280 °C")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/filament-catalog/")
    }

    @Test("firmwareUpdates cible /firmware/updates et décode la disponibilité")
    func fetchesFirmwareUpdates() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"updates":[{"printer_id":1,"printer_name":"VP-Test","model":"X1C","#
                + #""current_version":"01.07.00.00","latest_version":"01.11.02.00","update_available":true},"#
                + #"{"printer_id":2,"printer_name":"P1S","current_version":"1.0","latest_version":"1.0","#
                + #""update_available":false}]}"#
        )
        let client = try makeClient()
        let updates = try await client.firmwareUpdates()
        #expect(updates.updates?.count == 2)
        #expect(updates.availableCount == 1)
        #expect(updates.updates?.first?.isUpdateAvailable == true)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/firmware/updates")
    }

    @Test("performMaintenance POST /maintenance/items/{id}/perform et renvoie l'item")
    func performsMaintenance() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"id":1,"maintenance_type_name":"Clean Nozzle","is_due":false,"#
                + #""last_performed_at":"2026-06-04T08:26:52Z"}"#
        )
        let client = try makeClient()
        let item = try await client.performMaintenance(itemID: 1, notes: "done")
        #expect(item.isDueNow == false)
        #expect(item.lastPerformedAt == "2026-06-04T08:26:52Z")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString
            == "https://host.example.com/api/v1/maintenance/items/1/perform")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["notes"] as? String == "done")
    }

    @Test("printLog cible /print-log/ avec pagination et recherche, décode la page")
    func fetchesPrintLog() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"items":[{"id":1,"print_name":"Benchy","status":"completed","#
                + #""created_at":"2026-06-04T11:37:08"}],"total":1}"#
        )
        let client = try makeClient()
        let page = try await client.printLog(search: "Ben chy", limit: 25, offset: 0)
        #expect(page.total == 1)
        #expect(page.items.first?.printName == "Benchy")
        let request = try #require(MockURLProtocol.lastRequest)
        let url = try #require(request.url?.absoluteString)
        #expect(url.hasPrefix("https://host.example.com/api/v1/print-log/?"))
        #expect(url.contains("limit=25"))
        #expect(url.contains("offset=0"))
        #expect(url.contains("search=Ben%20chy"))
    }

    @Test("clearPrintLog DELETE /print-log/")
    func clearsPrintLog() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"message":"Print log cleared"}"#)
        let client = try makeClient()
        try await client.clearPrintLog()
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/print-log/")
    }

    @Test("gitHubBackupStatus cible /github-backup/status et décode")
    func fetchesGitHubBackupStatus() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"configured":true,"enabled":true,"is_running":false}"#)
        let client = try makeClient()
        let status = try await client.gitHubBackupStatus()
        #expect(status.configured == true)
        #expect(status.enabled == true)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/github-backup/status")
    }

    @Test("gitHubBackupConfig décode null en nil et le chemin est correct")
    func fetchesNilGitHubBackupConfig() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: "null")
        let client = try makeClient()
        let config = try await client.gitHubBackupConfig()
        #expect(config == nil)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/github-backup/config")
    }

    @Test("saveGitHubBackupConfig POST /github-backup/config avec le jeton dans le corps")
    func savesGitHubBackupConfig() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"id":1,"repository_url":"https://github.com/me/b","has_token":true,"branch":"main","#
                + #""provider":"github","allow_insecure_http":false,"schedule_enabled":false,"#
                + #""schedule_type":"daily","backup_kprofiles":true,"backup_cloud_profiles":true,"#
                + #""backup_settings":false,"backup_spools":false,"backup_archives":false,"enabled":true}"#
        )
        let client = try makeClient()
        let saved = try await client.saveGitHubBackupConfig(
            GitHubBackupConfigCreate(repositoryUrl: "https://github.com/me/b", accessToken: "tok")
        )
        #expect(saved.id == 1)
        #expect(saved.hasToken == true)
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/github-backup/config")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["access_token"] as? String == "tok")
    }

    @Test("gitHubBackupLogs et runGitHubBackup ciblent les bons chemins")
    func fetchesLogsAndRuns() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"[{"id":1,"config_id":1,"status":"success","trigger":"manual","files_changed":3}]"#
        )
        let client = try makeClient()
        let logs = try await client.gitHubBackupLogs()
        #expect(logs.first?.filesChanged == 3)
        var request = try #require(MockURLProtocol.lastRequest)
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/github-backup/logs")

        respond(status: 200, json: #"{"success":true,"message":"Backup complete","files_changed":3}"#)
        let result = try await client.runGitHubBackup()
        #expect(result.success == true)
        request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/github-backup/run")
    }

    @Test("updateGitHubBackupConfig PATCH n'encode que les champs renseignés (jeton préservé)")
    func patchesGitHubBackupConfig() async throws {
        MockURLProtocol.reset()
        respond(
            status: 200,
            json: #"{"id":1,"repository_url":"https://github.com/me/b","has_token":true,"branch":"dev","#
                + #""provider":"github","allow_insecure_http":false,"schedule_enabled":true,"#
                + #""schedule_type":"weekly","backup_kprofiles":true,"backup_cloud_profiles":true,"#
                + #""backup_settings":false,"backup_spools":false,"backup_archives":false,"enabled":true}"#
        )
        let client = try makeClient()
        let updated = try await client.updateGitHubBackupConfig(
            GitHubBackupConfigUpdate(branch: "dev", scheduleEnabled: true, scheduleType: "weekly")
        )
        #expect(updated.branch == "dev")
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "PATCH")
        let body = try #require(MockURLProtocol.lastBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        // Le jeton absent ne doit pas être encodé (exclude_unset → pas de clé access_token).
        #expect(json["access_token"] == nil)
        #expect(json["branch"] as? String == "dev")
        #expect(json["schedule_type"] as? String == "weekly")
    }

    @Test("deleteGitHubBackupConfig DELETE /github-backup/config")
    func deletesGitHubBackupConfig() async throws {
        MockURLProtocol.reset()
        respond(status: 200, json: #"{"message":"Configuration deleted"}"#)
        let client = try makeClient()
        try await client.deleteGitHubBackupConfig()
        let request = try #require(MockURLProtocol.lastRequest)
        #expect(request.httpMethod == "DELETE")
        #expect(request.url?.absoluteString == "https://host.example.com/api/v1/github-backup/config")
    }
}
