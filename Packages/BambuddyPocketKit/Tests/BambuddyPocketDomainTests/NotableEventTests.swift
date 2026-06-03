// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("WebSocketEvent.notableEvent")
struct NotableEventTests {
    @Test("print_complete devient une notification de fin")
    func mapsPrintComplete() {
        let event = WebSocketEvent.printComplete(printerID: 4, status: nil)
        #expect(event.notableEvent?.kind == .printCompleted)
        #expect(event.notableEvent?.printerID == 4)
    }

    @Test("missing_spool_assignment est notable")
    func mapsMissingSpool() {
        let event = WebSocketEvent.missingSpoolAssignment(printerID: 1, printerName: "X1C")
        #expect(event.notableEvent?.kind == .missingSpool)
    }

    @Test("printer_status et pong ne sont pas notables")
    func ignoresNonNotable() {
        #expect(WebSocketEvent.printerStatus(printerID: 1, status: PrinterStatus()).notableEvent == nil)
        #expect(WebSocketEvent.pong.notableEvent == nil)
    }

    @Test("plate_not_empty sans imprimante n'est pas notable")
    func plateWithoutPrinter() {
        #expect(WebSocketEvent.plateNotEmpty(printerID: nil).notableEvent == nil)
    }
}
