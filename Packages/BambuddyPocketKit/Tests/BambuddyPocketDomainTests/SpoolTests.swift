// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("Spool")
struct SpoolTests {
    @Test("Décode et calcule displayName / restant")
    func decodesAndComputes() throws {
        let json = #"""
        {"id":4,"material":"PLA","brand":"Bambu","color_name":"Black","rgba":"000000FF",
         "label_weight":1000,"weight_used":250}
        """#
        let data = try #require(json.data(using: .utf8))
        let spool = try JSONDecoder.bambuddy().decode(Spool.self, from: data)
        #expect(spool.displayName == "Bambu PLA")
        #expect(spool.colorName == "Black")
        #expect(spool.remainingGrams == 750)
        #expect(spool.remainingFraction == 0.75)
    }

    @Test("displayName inclut le sous-type et tolère l'absence de marque")
    func displayNameVariants() {
        var spool = Spool(id: 1, material: "PETG")
        #expect(spool.displayName == "PETG")
        spool.subtype = "HF"
        #expect(spool.displayName == "PETG HF")
    }

    @Test("SpoolUpdate omet les champs nil à l'encodage")
    func updateOmitsNilFields() throws {
        let update = SpoolUpdate(storageLocation: "A", note: "sèche")
        let data = try JSONEncoder.bambuddy().encode(update)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["storage_location"] as? String == "A")
        #expect(json["note"] as? String == "sèche")
        #expect(json.keys.contains("material") == false)
        #expect(json.keys.contains("cost_per_kg") == false)
    }

    @Test("Décode une entrée d'historique de consommation")
    func decodesUsage() throws {
        let json = #"""
        {"id":2,"spool_id":4,"printer_id":1,"print_name":"Cube","weight_used":12.5,
         "percent_used":3,"status":"completed","cost":0.31,"created_at":"2026-06-01T10:00:00Z"}
        """#
        let data = try #require(json.data(using: .utf8))
        let usage = try JSONDecoder.bambuddy().decode(SpoolUsage.self, from: data)
        #expect(usage.weightUsed == 12.5)
        #expect(usage.percentUsed == 3)
        #expect(usage.printName == "Cube")
        #expect(usage.cost == 0.31)
    }
}
