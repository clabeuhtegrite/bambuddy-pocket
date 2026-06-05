// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

@MainActor
@Suite("ServerNotificationCenter")
struct ServerNotificationCenterTests {
    private func makeCenter() throws -> ServerNotificationCenter {
        let environment = AppEnvironment.inMemory()
        let url = try #require(URL(string: "http://host:8000"))
        let server = try ServerConfiguration(label: "Atelier", baseURL: url)
        let center = ServerNotificationCenter(
            server: server,
            connectionFactory: environment.connectionFactory
        )
        center.updatePrinterNames(from: [Printer(id: 1, name: "X1C")])
        return center
    }

    @Test("print_complete crée une notification non lue et une bannière")
    func recordsPrintComplete() throws {
        let center = try makeCenter()
        var status = PrinterStatus()
        status.subtaskName = "benchy.3mf"
        center.ingest(.printComplete(printerID: 1, status: status))

        #expect(center.notifications.count == 1)
        #expect(center.unreadCount == 1)
        let note = try #require(center.notifications.first)
        #expect(note.kind == .printCompleted)
        #expect(note.printerName == "X1C")
        #expect(note.detail == "benchy.3mf")
        #expect(center.latestBanner?.id == note.id)
    }

    @Test("markAllAsRead remet le compteur de non-lus à zéro")
    func marksAllRead() throws {
        let center = try makeCenter()
        center.ingest(.printStart(printerID: 1, status: nil))
        center.ingest(.printComplete(printerID: 1, status: nil))
        #expect(center.unreadCount == 2)

        center.markAllAsRead()
        #expect(center.unreadCount == 0)
        #expect(center.notifications.count == 2)
    }

    @Test("printer_status fusionne le delta sans créer de notification")
    func mergesStatusSilently() throws {
        let center = try makeCenter()
        var delta = PrinterStatus()
        delta.state = .running
        delta.progress = 30
        center.ingest(.printerStatus(printerID: 1, status: delta))

        #expect(center.notifications.isEmpty)
        #expect(center.status(for: 1)?.state == .running)
        #expect(center.status(for: 1)?.progress == 30)
    }

    @Test("Une erreur HMS grave notifie une seule fois (transition)")
    func severeHMSNotifiesOnce() throws {
        let center = try makeCenter()
        var withError = PrinterStatus()
        // 0700_4001 (connu) ; attr 0x07000200 → module 0x0700, quartet de gravité 2 (serious).
        withError.hmsErrors = [HMSError(code: "0x4001", attr: 0x0700_0200)]
        center.ingest(.printerStatus(printerID: 1, status: withError))
        center.ingest(.printerStatus(printerID: 1, status: withError))

        let hms = center.notifications.filter { $0.kind == .hmsError }
        #expect(hms.count == 1)
        #expect(hms.first?.detail == "HMS 0700_4001")
    }

    @Test("Un HMS informatif (X2D 0x30027, sev. effective .info) ne notifie pas")
    func informationalHMSDoesNotNotify() throws {
        let center = try makeCenter()
        var status = PrinterStatus()
        // Code réel X2D : champ severity:2 mais quartet d'attr → gravité 0 → .info.
        status.hmsErrors = [HMSError(code: "0x30027", attr: 0x0503_0000, module: 5, severity: 2)]
        center.ingest(.printerStatus(printerID: 1, status: status))

        #expect(center.notifications.count(where: { $0.kind == .hmsError }) == 0)
    }

    @Test("Une erreur grave qui clignote ne ré-alarme pas dans la fenêtre de grâce")
    func flappingSevereHMSDoesNotReAlarmWithinGrace() throws {
        let center = try makeCenter()
        var withError = PrinterStatus()
        // 0700_4001 (connu, grave) ; attr 0x07000200 → module 0x0700, quartet de gravité 2.
        withError.hmsErrors = [HMSError(code: "0x4001", attr: 0x0700_0200)]
        var clear = PrinterStatus()
        clear.hmsErrors = [] // delta explicite : la liste se vide (sinon le merge conserve l'ancienne)

        center.ingest(.printerStatus(printerID: 1, status: withError))
        center.ingest(.printerStatus(printerID: 1, status: clear))
        center.ingest(.printerStatus(printerID: 1, status: withError)) // réapparition immédiate

        // Une seule notification malgré l'apparition → disparition → réapparition rapprochée.
        #expect(center.notifications.count(where: { $0.kind == .hmsError }) == 1)
    }

    @Test("clear vide le feed et la bannière")
    func clearsFeed() throws {
        let center = try makeCenter()
        center.ingest(.printComplete(printerID: 1, status: nil))
        center.clear()

        #expect(center.notifications.isEmpty)
        #expect(center.latestBanner == nil)
    }
}
