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
}
