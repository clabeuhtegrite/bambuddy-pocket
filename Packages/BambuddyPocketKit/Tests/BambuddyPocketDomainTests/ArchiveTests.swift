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

    @Test("Décode les chemins de média (vignette/timelapse) et expose la disponibilité")
    func decodesMediaPaths() throws {
        let json = #"""
        {"id":2,"status":"completed","thumbnail_path":"thumbs/2.png",
         "timelapse_path":null,"object_count":4}
        """#
        let data = try #require(json.data(using: .utf8))
        let archive = try JSONDecoder.bambuddy().decode(Archive.self, from: data)
        #expect(archive.hasThumbnail)
        #expect(archive.hasTimelapse == false)
        #expect(archive.objectCount == 4)
    }

    @Test("Décode les métadonnées timelapse (résolution dérivée)")
    func decodesTimelapseInfo() throws {
        let json = #"""
        {"duration":42.5,"width":1920,"height":1080,"fps":30.0,
         "codec":"h264","file_size":1048576,"has_audio":false}
        """#
        let data = try #require(json.data(using: .utf8))
        let info = try JSONDecoder.bambuddy().decode(TimelapseInfo.self, from: data)
        #expect(info.duration == 42.5)
        #expect(info.resolution == "1920 × 1080")
        #expect(info.hasAudio == false)
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
