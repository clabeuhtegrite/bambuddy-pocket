// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("WebSocketEvent.notableEvent")
struct NotableEventTests {
    @Test("print_complete devient une notification de fin avec le nom du travail")
    func mapsPrintComplete() {
        var status = PrinterStatus()
        status.subtaskName = "benchy.3mf"
        let event = WebSocketEvent.printComplete(printerID: 4, status: status)
        #expect(event.notableEvent?.kind == .printCompleted)
        #expect(event.notableEvent?.printerID == 4)
        #expect(event.notableEvent?.detail == "benchy.3mf")
    }

    @Test("print_start sans données ne porte pas de détail")
    func mapsPrintStartWithoutDetail() {
        let event = WebSocketEvent.printStart(printerID: 2, status: nil)
        #expect(event.notableEvent?.kind == .printStarted)
        #expect(event.notableEvent?.detail == nil)
    }

    @Test("missing_spool_assignment est notable et porte le nom de l'imprimante")
    func mapsMissingSpool() {
        let event = WebSocketEvent.missingSpoolAssignment(printerID: 1, printerName: "X1C")
        #expect(event.notableEvent?.kind == .missingSpool)
        #expect(event.notableEvent?.detail == "X1C")
    }

    @Test("plate_not_empty avec imprimante porte son message")
    func mapsPlateNotEmpty() {
        let event = WebSocketEvent.plateNotEmpty(printerID: 3, printerName: "X1C", message: "Objects!")
        #expect(event.notableEvent?.kind == .plateNotEmpty)
        #expect(event.notableEvent?.printerID == 3)
        #expect(event.notableEvent?.detail == "Objects!")
    }

    @Test("archive_created est notable sans imprimante")
    func mapsArchiveCreated() {
        let event = WebSocketEvent.archiveCreated(name: "Cool print")
        #expect(event.notableEvent?.kind == .archiveCreated)
        #expect(event.notableEvent?.printerID == nil)
        #expect(event.notableEvent?.detail == "Cool print")
    }

    @Test("printer_status et pong ne sont pas notables")
    func ignoresNonNotable() {
        #expect(WebSocketEvent.printerStatus(printerID: 1, status: PrinterStatus()).notableEvent == nil)
        #expect(WebSocketEvent.pong.notableEvent == nil)
    }

    @Test("plate_not_empty sans imprimante n'est pas notable")
    func plateWithoutPrinter() {
        #expect(WebSocketEvent.plateNotEmpty(printerID: nil, printerName: nil, message: nil).notableEvent == nil)
    }
}

@Suite("PrinterStatus.severeHMSEvent")
struct SevereHMSEventTests {
    private func status(severeCode: String?, severity: Int = 1) -> PrinterStatus {
        var status = PrinterStatus()
        if let severeCode {
            status.hmsErrors = [HMSError(code: severeCode, severity: severity)]
        } else {
            status.hmsErrors = []
        }
        return status
    }

    @Test("Une nouvelle erreur fatale produit une notification HMS")
    func detectsNewSevereError() {
        let current = status(severeCode: "0300_0100", severity: 1)
        let event = current.severeHMSEvent(comparedTo: status(severeCode: nil), printerID: 7)
        #expect(event?.kind == .hmsError)
        #expect(event?.printerID == 7)
        #expect(event?.detail == "0300_0100")
    }

    @Test("Une erreur déjà présente ne renotifie pas")
    func ignoresExistingError() {
        let previous = status(severeCode: "0300_0100", severity: 1)
        let current = status(severeCode: "0300_0100", severity: 1)
        #expect(current.severeHMSEvent(comparedTo: previous, printerID: 1) == nil)
    }

    @Test("Une erreur de faible gravité n'est pas notable")
    func ignoresLowSeverity() {
        let current = status(severeCode: "0500_0200", severity: 4)
        #expect(current.severeHMSEvent(comparedTo: status(severeCode: nil), printerID: 1) == nil)
    }

    @Test("Sans erreur, aucune notification")
    func noErrorNoEvent() {
        let current = status(severeCode: nil)
        #expect(current.severeHMSEvent(comparedTo: nil, printerID: 1) == nil)
    }
}
