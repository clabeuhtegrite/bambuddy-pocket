// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("ProjectItems")
struct ProjectItemsTests {
    @Test("Décode un élément de nomenclature (BOM)")
    func decodesBOMItem() throws {
        let json = #"""
        {"id":1,"project_id":1,"name":"M3 screws","quantity_needed":8,"quantity_acquired":2,
         "unit_price":0.05,"sourcing_url":null,"archive_id":null,"archive_name":null,
         "stl_filename":null,"remarks":"hardware","sort_order":1,"is_complete":false,
         "created_at":"2026-06-04T13:59:58","updated_at":"2026-06-04T13:59:58"}
        """#
        let data = try #require(json.data(using: .utf8))
        let item = try JSONDecoder.bambuddy().decode(BOMItem.self, from: data)
        #expect(item.name == "M3 screws")
        #expect(item.quantityNeeded == 8)
        #expect(item.quantityAcquired == 2)
        #expect(item.unitPrice == 0.05)
        #expect(item.remarks == "hardware")
        #expect(item.complete == false)
        #expect(item.lineTotal == 0.4)
    }

    @Test("Encode la création d'un élément BOM (champs nil omis)")
    func encodesBOMCreate() throws {
        let data = try JSONEncoder.bambuddy().encode(
            BOMItemCreate(name: "Insert", quantityNeeded: 4, unitPrice: 0.1)
        )
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["name"] as? String == "Insert")
        #expect(json["quantity_needed"] as? Int == 4)
        #expect(json["unit_price"] as? Double == 0.1)
        #expect(json["sourcing_url"] == nil)
        #expect(json["remarks"] == nil)
    }

    @Test("Décode un événement de chronologie (description renommée en details)")
    func decodesTimelineEvent() throws {
        let json = #"""
        [{"event_type":"project_created","timestamp":"2026-06-04T05:31:27",
          "title":"Project created","description":"Project 'Box' was created","metadata":null}]
        """#
        let data = try #require(json.data(using: .utf8))
        let events = try JSONDecoder.bambuddy().decode([TimelineEvent].self, from: data)
        let event = try #require(events.first)
        #expect(event.eventType == "project_created")
        #expect(event.title == "Project created")
        #expect(event.details == "Project 'Box' was created")
        #expect(!event.id.isEmpty)
    }
}
