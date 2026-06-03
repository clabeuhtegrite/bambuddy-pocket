// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("Archive")
struct ArchiveTests {
    @Test("Décode un sous-ensemble d'ArchiveResponse")
    func decodesSubset() throws {
        let json = #"""
        {"id":7,"status":"success","print_name":"Benchy","filament_used_grams":12.5,
         "created_at":"2026-01-01T10:00:00Z","total_layers":120}
        """#
        let data = try #require(json.data(using: .utf8))
        let archive = try JSONDecoder.bambuddy().decode(Archive.self, from: data)
        #expect(archive.id == 7)
        #expect(archive.displayName == "Benchy")
        #expect(archive.filamentUsedGrams == 12.5)
        #expect(archive.totalLayers == 120)
        #expect(archive.createdAt == "2026-01-01T10:00:00Z")
    }

    @Test("displayName retombe sur le fichier puis sur #id")
    func displayNameFallback() {
        var archive = Archive(id: 3, status: "failed")
        #expect(archive.displayName == "#3")
        archive.filename = "plate_1.gcode.3mf"
        #expect(archive.displayName == "plate_1.gcode.3mf")
    }

    @Test("Décode tags/notes/external_url et découpe les étiquettes")
    func decodesMetadata() throws {
        let json = #"""
        {"id":1,"status":"completed","tags":"calibration, test ,",
         "notes":"première impression","external_url":"https://example.com","is_favorite":true}
        """#
        let data = try #require(json.data(using: .utf8))
        let archive = try JSONDecoder.bambuddy().decode(Archive.self, from: data)
        #expect(archive.tagList == ["calibration", "test"])
        #expect(archive.notes == "première impression")
        #expect(archive.externalUrl == "https://example.com")
        #expect(archive.isFavorite == true)
    }

    @Test("ArchiveUpdate omet les champs nil à l'encodage")
    func updateOmitsNilFields() throws {
        let update = ArchiveUpdate(tags: "a,b", isFavorite: true)
        let data = try JSONEncoder.bambuddy().encode(update)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["tags"] as? String == "a,b")
        #expect(json["is_favorite"] as? Bool == true)
        #expect(json.keys.contains("notes") == false)
        #expect(json.keys.contains("cost") == false)
    }
}
