// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("WebSocketEvent")
struct WebSocketEventTests {
    private func decode(_ json: String) throws -> WebSocketEvent {
        let data = try #require(json.data(using: .utf8))
        return try JSONDecoder.bambuddy().decode(WebSocketEvent.self, from: data)
    }

    @Test("Décode un printer_status et fusionne le delta")
    func decodesPrinterStatus() throws {
        let event = try decode(#"""
        {"type":"printer_status","printer_id":7,"data":{"state":"RUNNING","progress":42}}
        """#)
        guard case let .printerStatus(printerID, status) = event else {
            Issue.record("type inattendu : \(event)")
            return
        }
        #expect(printerID == 7)
        #expect(status.state == .running)
        #expect(status.progress == 42)
    }

    @Test("Décode print_complete avec son identifiant")
    func decodesPrintComplete() throws {
        let event = try decode(#"{"type":"print_complete","printer_id":3,"data":{}}"#)
        #expect(event == .printComplete(printerID: 3, status: PrinterStatus()))
        #expect(event.printerID == 3)
    }

    @Test("Décode missing_spool_assignment avec le nom de l'imprimante")
    func decodesMissingSpool() throws {
        let event = try decode(#"""
        {"type":"missing_spool_assignment","printer_id":1,"printer_name":"X1C"}
        """#)
        #expect(event == .missingSpoolAssignment(printerID: 1, printerName: "X1C"))
    }

    @Test("Décode plate_not_empty avec son message")
    func decodesPlateNotEmpty() throws {
        let event = try decode(#"""
        {"type":"plate_not_empty","printer_id":2,"printer_name":"X1C","message":"Objects detected!"}
        """#)
        #expect(event == .plateNotEmpty(printerID: 2, printerName: "X1C", message: "Objects detected!"))
        #expect(event.printerID == 2)
    }

    @Test("Décode archive_created en extrayant un libellé")
    func decodesArchiveCreated() throws {
        let event = try decode(#"""
        {"type":"archive_created","data":{"name":"Benchy","file_name":"benchy.3mf"}}
        """#)
        #expect(event == .archiveCreated(name: "Benchy"))
    }

    @Test("Décode pong")
    func decodesPong() throws {
        #expect(try decode(#"{"type":"pong"}"#) == .pong)
    }

    @Test("Un type inconnu retombe sur .other")
    func decodesUnknown() throws {
        #expect(try decode(#"{"type":"inventory_changed"}"#) == .other(type: "inventory_changed"))
    }

    @Test("Décode background_dispatch avec travaux actifs et en attente")
    func decodesBackgroundDispatch() throws {
        let event = try decode(#"""
        {"type":"background_dispatch","data":{"total":3,"dispatched":1,"processing":1,
         "completed":1,"failed":0,
         "active_jobs":[{"job_id":10,"kind":"reprint_archive","source_name":"Gear",
           "printer_id":2,"printer_name":"X1","upload_progress_pct":42.5}],
         "dispatched_jobs":[{"job_id":11,"source_name":"Bracket","printer_id":2}]}}
        """#)
        guard case let .backgroundDispatch(state) = event else {
            Issue.record("type inattendu : \(event)")
            return
        }
        #expect(state.isActive)
        #expect(state.processing == 1)
        #expect(state.activeJobs.first?.jobID == 10)
        #expect(state.activeJobs.first?.uploadProgressPct == 42.5)
        #expect(state.dispatchedJobs.first?.sourceName == "Bracket")
    }
}

@Suite("PrinterStatus.merged")
struct PrinterStatusMergeTests {
    @Test("Le delta remplace les champs présents et conserve les absents")
    func mergesDelta() {
        var current = PrinterStatus()
        current.state = .idle
        current.progress = 10
        current.layerNum = 5

        var delta = PrinterStatus()
        delta.state = .running
        delta.progress = 55

        let merged = current.merged(with: delta)
        #expect(merged.state == .running)
        #expect(merged.progress == 55)
        #expect(merged.layerNum == 5)
    }

    @Test("Un delta vide ne modifie rien")
    func emptyDeltaKeepsState() {
        var current = PrinterStatus()
        current.state = .pause
        current.remainingTime = 30
        let merged = current.merged(with: PrinterStatus())
        #expect(merged == current)
    }
}
