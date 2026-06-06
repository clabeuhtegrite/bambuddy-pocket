// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// Garantit que les fixtures du **mode démo** (captures App Store) décodent vers les modèles de
/// domaine réels — sinon les écrans de démo afficheraient un état vide / erreur.
@Suite("Mode démo — fixtures & routage")
struct DemoFixturesTests {
    private let decoder = JSONDecoder.bambuddy()

    private func decode<T: Decodable>(_: T.Type, _ json: String) throws -> T {
        try decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test("Liste d'imprimantes : deux imprimantes nommées")
    func printersDecode() throws {
        let printers = try decode([Printer].self, DemoFixtures.printers)
        #expect(printers.count == 2)
        #expect(printers.first?.name.isEmpty == false)
    }

    @Test("Statut en cours : impression active à 47 %, AMS présent")
    func printerStatusDecodes() throws {
        let status = try decode(PrinterStatus.self, DemoFixtures.printerStatus)
        #expect(status.connected == true)
        #expect(status.progressFraction.map { $0 > 0.4 && $0 < 0.5 } == true)
        #expect(status.ams?.isEmpty == false)
        #expect(status.hmsErrors?.isEmpty ?? true)
    }

    @Test("Statut au repos décode")
    func idleStatusDecodes() throws {
        let status = try decode(PrinterStatus.self, DemoFixtures.printerStatusIdle)
        #expect(status.currentPrint == nil)
    }

    @Test("Archives : cinq entrées avec favoris")
    func archivesDecode() throws {
        let archives = try decode([Archive].self, DemoFixtures.archives)
        #expect(archives.count == 5)
        #expect(archives.contains { $0.isFavorite == true })
    }

    @Test("File d'attente et bibliothèque décodent")
    func queueAndLibraryDecode() throws {
        let queue = try decode([QueueItem].self, DemoFixtures.queue)
        let library = try decode([LibraryFile].self, DemoFixtures.libraryFiles)
        #expect(queue.count == 4)
        #expect(library.count == 4)
    }

    @Test("Routeur : imprimante 1 en cours, imprimante 2 au repos")
    func routerDistinguishesPrinters() {
        let (status1, body1) = DemoRouter.response(forPath: "/api/v1/printers/1/status", query: nil)
        let (status2, body2) = DemoRouter.response(forPath: "/api/v1/printers/2/status", query: nil)
        #expect(status1 == 200)
        #expect(status2 == 200)
        #expect(body1 != body2)
    }

    @Test("Routeur : téléchargement d'archive → G-code non vide")
    func routerServesToolpath() {
        let (status, body) = DemoRouter.response(forPath: "/api/v1/archives/1/download", query: nil)
        #expect(status == 200)
        let text = String(bytes: body, encoding: .utf8) ?? ""
        #expect(text.contains("G1"))
        #expect(DemoRouter.contentType(forPath: "/api/v1/archives/1/download").contains("text/plain"))
    }

    @Test("Routeur : chemin inconnu → liste vide 200 (pas d'erreur à l'écran)")
    func routerFallsBackGracefully() {
        let (status, body) = DemoRouter.response(forPath: "/api/v1/unknown/thing", query: nil)
        #expect(status == 200)
        #expect(String(bytes: body, encoding: .utf8) == "[]")
    }
}
