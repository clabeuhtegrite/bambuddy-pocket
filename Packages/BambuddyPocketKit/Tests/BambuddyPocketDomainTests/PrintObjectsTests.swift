// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("PrintObjects")
struct PrintObjectsTests {
    @Test("Décode la réponse de /print/objects (objets + métadonnées)")
    func decodesResponse() throws {
        let json = #"""
        {"objects":[{"id":1,"name":"Gear","x":12.5,"y":30.0,"skipped":false},
         {"id":2,"name":"Bracket","x":null,"y":null,"skipped":true}],
         "total":2,"skipped_count":1,"is_printing":true,"bbox_all":null}
        """#
        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder.bambuddy().decode(PrintObjects.self, from: data)
        #expect(result.total == 2)
        #expect(result.skippedCount == 1)
        #expect(result.isPrinting)
        #expect(result.objects.count == 2)
        #expect(result.objects.first?.name == "Gear")
        #expect(result.objects.first?.x == 12.5)
        #expect(result.objects.last?.skipped == true)
        #expect(result.objects.last?.x == nil)
    }

    @Test("Décode une plaque vide (aucun objet)")
    func decodesEmpty() throws {
        let json = #"{"objects":[],"total":0,"skipped_count":0,"is_printing":false,"bbox_all":null}"#
        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder.bambuddy().decode(PrintObjects.self, from: data)
        #expect(result.objects.isEmpty)
        #expect(result.isPrinting == false)
    }
}
