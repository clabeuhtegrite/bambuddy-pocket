// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("QueueItem")
struct QueueItemTests {
    @Test("Décode un sous-ensemble de PrintQueueItemResponse")
    func decodesSubset() throws {
        let json = #"""
        {"id":5,"position":2,"status":"printing","printer_name":"X1C","archive_name":"Gear",
         "print_time_seconds":3600,"been_jumped":false}
        """#
        let data = try #require(json.data(using: .utf8))
        let item = try JSONDecoder.bambuddy().decode(QueueItem.self, from: data)
        #expect(item.id == 5)
        #expect(item.position == 2)
        #expect(item.status == "printing")
        #expect(item.printerName == "X1C")
        #expect(item.displayName == "Gear")
        #expect(item.printTimeSeconds == 3600)
    }

    @Test("displayName retombe sur le fichier de bibliothèque puis sur #id")
    func displayNameFallback() {
        var item = QueueItem(id: 9, position: 1, status: "pending")
        #expect(item.displayName == "#9")
        item.libraryFileName = "bracket.3mf"
        #expect(item.displayName == "bracket.3mf")
    }
}
