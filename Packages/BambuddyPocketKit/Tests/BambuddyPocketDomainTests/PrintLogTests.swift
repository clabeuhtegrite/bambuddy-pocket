// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("PrintLog")
struct PrintLogTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.bambuddy().decode(type, from: Data(json.utf8))
    }

    /// Charge réelle observée sur le Docker (`GET /print-log/`) après seed d'une entrée.
    @Test("PrintLogPage décode la charge réelle (dates ISO sans fuseau, champs nuls)")
    func decodesRealPayload() throws {
        let json = #"""
        {"items":[{"id":1,"archive_id":null,"print_name":"Benchy test","printer_name":"VP-Test",
        "printer_id":1,"status":"completed","started_at":"2026-06-04T10:37:08.696504",
        "completed_at":"2026-06-04T11:37:08.696504","duration_seconds":3600,"filament_type":"PLA",
        "filament_color":"#00AE42","filament_used_grams":12.5,"cost":null,"energy_kwh":null,
        "energy_cost":null,"failure_reason":null,"thumbnail_path":null,"created_by_id":null,
        "created_by_username":"admin","created_at":"2026-06-04T11:37:08"}],"total":1}
        """#
        let page = try decode(PrintLogPage.self, json)
        #expect(page.total == 1)
        let entry = try #require(page.items.first)
        #expect(entry.id == 1)
        #expect(entry.printName == "Benchy test")
        #expect(entry.printerName == "VP-Test")
        #expect(entry.status == "completed")
        #expect(entry.durationSeconds == 3600)
        #expect(entry.filamentType == "PLA")
        #expect(entry.filamentColor == "#00AE42")
        #expect(entry.filamentUsedGrams == 12.5)
        #expect(entry.createdByUsername == "admin")
        #expect(entry.createdAt == "2026-06-04T11:37:08")
        #expect(entry.archiveID == nil)
    }

    @Test("PrintLogPage décode une page vide")
    func decodesEmptyPage() throws {
        let page = try decode(PrintLogPage.self, #"{"items":[],"total":0}"#)
        #expect(page.items.isEmpty)
        #expect(page.total == 0)
    }

    @Test("PrintLogEntry décode une entrée d'échec avec raison")
    func decodesFailure() throws {
        let entry = try decode(
            PrintLogEntry.self,
            #"{"id":2,"status":"failed","failure_reason":"Spaghetti detected","print_name":"Vase"}"#
        )
        #expect(entry.status == "failed")
        #expect(entry.failureReason == "Spaghetti detected")
    }
}
