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
    /// Construit un statut avec une unique erreur HMS. `attr` encode le module (`>>16`) et la gravité
    /// (quartet `>>8`) ; sans `attr`, le code est *inconnu* (non calculable) et donc masqué, comme la
    /// web UI. Les tests fournissent donc un `attr` cohérent avec un code court catalogué.
    private func status(code: String?, attr: Int? = nil) -> PrinterStatus {
        var status = PrinterStatus()
        if let code {
            status.hmsErrors = [HMSError(code: code, attr: attr)]
        } else {
            status.hmsErrors = []
        }
        return status
    }

    @Test("Une nouvelle erreur grave connue produit une notification HMS")
    func detectsNewSevereError() {
        // 0700_4001 (connu, série AMS) ; attr 0x07000200 → module 0x0700, quartet de gravité 2 (serious).
        let current = status(code: "0x4001", attr: 0x0700_0200)
        let event = current.severeHMSEvent(comparedTo: status(code: nil), printerID: 7)
        #expect(event?.kind == .hmsError)
        #expect(event?.printerID == 7)
        #expect(event?.detail == "HMS 0700_4001")
    }

    @Test("Une erreur déjà présente ne renotifie pas")
    func ignoresExistingError() {
        let previous = status(code: "0x4001", attr: 0x0700_0200)
        let current = status(code: "0x4001", attr: 0x0700_0200)
        #expect(current.severeHMSEvent(comparedTo: previous, printerID: 1) == nil)
    }

    @Test("Une erreur de faible gravité n'est pas notable")
    func ignoresLowSeverity() {
        // 0700_4025 (connu) mais quartet de gravité 4 → .info → non alarmant.
        let current = status(code: "0x4025", attr: 0x0700_0400)
        #expect(current.severeHMSEvent(comparedTo: status(code: nil), printerID: 1) == nil)
    }

    @Test("Une erreur grave mais inconnue (hors catalogue web) n'est pas notable")
    func ignoresUnknownSevereCode() {
        // 0500_0070 réel (X2D) : quartet de gravité 1 (fatal) mais code absent du catalogue web → masqué.
        let current = status(code: "0x70", attr: 0x0500_0100)
        #expect(current.severeHMSEvent(comparedTo: status(code: nil), printerID: 1) == nil)
    }

    @Test("Sans erreur, aucune notification")
    func noErrorNoEvent() {
        let current = status(code: nil)
        #expect(current.severeHMSEvent(comparedTo: nil, printerID: 1) == nil)
    }

    @Test("La gravité effective vient d'attr : un code X2D info ne notifie pas")
    func attrDerivedSeverityFilters() {
        var current = PrinterStatus()
        // 0x30027 réel : attr 0x05030000 → quartet de gravité 0 → .info, malgré severity:2.
        current.hmsErrors = [HMSError(code: "0x30027", attr: 0x0503_0000, module: 5, severity: 2)]
        #expect(current.severeHMSEvent(comparedTo: nil, printerID: 1) == nil)
    }

    @Test("Une erreur réellement grave notifie avec un libellé humain (pas le code brut)")
    func severeNotifiesWithHumanLabel() {
        var current = PrinterStatus()
        // 0300_8000 (connu : « Printing was paused… ») ; attr 0x03000100 → module 0x0300, quartet 1 (fatal).
        current.hmsErrors = [HMSError(code: "0x8000", attr: 0x0300_0100, module: 3, severity: 1)]
        let event = current.severeHMSEvent(comparedTo: nil, printerID: 1)
        #expect(event?.kind == .hmsError)
        #expect(event?.detail == "HMS 0300_8000")
    }
}
