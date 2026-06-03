// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("LibraryFile")
struct LibraryFileTests {
    @Test("Décode un sous-ensemble de FileListResponse et calcule displayName")
    func decodesSubset() throws {
        let json = #"""
        {"id":2,"filename":"gear.gcode.3mf","file_type":"3mf","file_size":4096,
         "print_count":3,"print_name":"Gear","notes":"hi","folder_id":7,"sliced_for_model":"P1S"}
        """#
        let data = try #require(json.data(using: .utf8))
        let file = try JSONDecoder.bambuddy().decode(LibraryFile.self, from: data)
        #expect(file.displayName == "Gear")
        #expect(file.notes == "hi")
        #expect(file.folderId == 7)
        #expect(file.slicedForModel == "P1S")
    }

    @Test("isSliced reconnaît .gcode et .gcode.3mf")
    func recognizesSlicedFiles() {
        #expect(LibraryFile(id: 1, filename: "a.gcode.3mf").isSliced)
        #expect(LibraryFile(id: 2, filename: "b.GCODE").isSliced)
        #expect(LibraryFile(id: 3, filename: "model.3mf").isSliced == false)
        #expect(LibraryFile(id: 4, filename: "shape.stl").isSliced == false)
    }

    @Test("LibraryFileUpdate omet les champs nil à l'encodage")
    func updateOmitsNilFields() throws {
        let update = LibraryFileUpdate(filename: "x.gcode.3mf", notes: "n")
        let data = try JSONEncoder.bambuddy().encode(update)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["filename"] as? String == "x.gcode.3mf")
        #expect(json["notes"] as? String == "n")
        #expect(json.keys.contains("folder_id") == false)
        #expect(json.keys.contains("project_id") == false)
    }
}
