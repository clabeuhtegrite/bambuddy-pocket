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
}
