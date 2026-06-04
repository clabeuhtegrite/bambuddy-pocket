// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("KProfile")
struct KProfileTests {
    @Test("Décode la réponse /kprofiles/ (profils + diamètre de buse)")
    func decodesResponse() throws {
        let json = #"""
        {"profiles":[
          {"slot_id":1,"extruder_id":0,"nozzle_id":"H","nozzle_diameter":"0.4",
           "filament_id":"GFA00","name":"PLA Basic","k_value":"0.020000",
           "n_coef":"0.000000","ams_id":0,"tray_id":2,"setting_id":"GFSA00"},
          {"slot_id":2,"nozzle_id":"H","nozzle_diameter":"0.4","filament_id":"GFB00",
           "name":"PETG","k_value":"0.035000"}],
         "nozzle_diameter":"0.4"}
        """#
        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder.bambuddy().decode(KProfilesResponse.self, from: data)
        #expect(result.nozzleDiameter == "0.4")
        #expect(result.profiles.count == 2)
        let first = try #require(result.profiles.first)
        #expect(first.slotID == 1)
        #expect(first.name == "PLA Basic")
        #expect(first.kValue == "0.020000")
        #expect(first.trayID == 2)
        #expect(first.settingID == "GFSA00")
        // Champs optionnels absents sur le second profil.
        let second = result.profiles[1]
        #expect(second.settingID == nil)
        #expect(second.nCoef == nil)
        #expect(second.id == 2)
    }

    @Test("Décode une imprimante sans profil")
    func decodesEmpty() throws {
        let json = #"{"profiles":[],"nozzle_diameter":"0.4"}"#
        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder.bambuddy().decode(KProfilesResponse.self, from: data)
        #expect(result.profiles.isEmpty)
    }

    @Test("Décode les notes de profils (dictionnaire setting_id → note)")
    func decodesNotes() throws {
        let json = #"{"notes":{"GFSA00":"Réglage maison","GFB00":""}}"#
        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder.bambuddy().decode(KProfileNotes.self, from: data)
        #expect(result.notes["GFSA00"] == "Réglage maison")
        #expect(result.notes.count == 2)
    }
}
