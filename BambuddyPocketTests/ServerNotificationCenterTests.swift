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
        withError.hmsErrors = [HMSError(code: "0300_0100", severity: 1)]
        center.ingest(.printerStatus(printerID: 1, status: withError))
        center.ingest(.printerStatus(printerID: 1, status: withError))

        let hms = center.notifications.filter { $0.kind == .hmsError }
        #expect(hms.count == 1)
        #expect(hms.first?.detail == "0300_0100")
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
