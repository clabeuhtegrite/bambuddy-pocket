// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("Project")
struct ProjectTests {
    @Test("Décode la liste (description → details, progress)")
    func decodesListItem() throws {
        let json = #"""
        {"id":1,"name":"Gridfinity","status":"active","description":"Bins","progress_percent":50,
         "target_count":10,"budget":25.0,"tags":"org"}
        """#
        let data = try #require(json.data(using: .utf8))
        let project = try JSONDecoder.bambuddy().decode(Project.self, from: data)
        #expect(project.details == "Bins")
        #expect(project.progressFraction == 0.5)
        #expect(project.targetCount == 10)
        #expect(project.budget == 25.0)
    }

    @Test("ProjectCreate encode name + priority et omet les champs nil")
    func createEncodes() throws {
        let create = ProjectCreate(name: "New", targetCount: 5, priority: "high")
        let data = try JSONEncoder.bambuddy().encode(create)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["name"] as? String == "New")
        #expect(json["target_count"] as? Int == 5)
        #expect(json["priority"] as? String == "high")
        #expect(json.keys.contains("description") == false)
        #expect(json.keys.contains("budget") == false)
    }

    @Test("ProjectUpdate omet les champs nil à l'encodage")
    func updateOmitsNilFields() throws {
        let update = ProjectUpdate(status: "completed", notes: "fini")
        let data = try JSONEncoder.bambuddy().encode(update)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["status"] as? String == "completed")
        #expect(json["notes"] as? String == "fini")
        #expect(json.keys.contains("name") == false)
        #expect(json.keys.contains("priority") == false)
    }
}
