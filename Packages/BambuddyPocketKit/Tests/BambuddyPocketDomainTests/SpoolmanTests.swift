// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("Spoolman")
struct SpoolmanTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.bambuddy().decode(type, from: Data(json.utf8))
    }

    /// Charge réelle observée sur le Docker (`GET /spoolman/status`) intégration désactivée.
    @Test("SpoolmanStatus décode l'état désactivé (url null)")
    func decodesDisabledStatus() throws {
        let status = try decode(SpoolmanStatus.self, #"{"enabled":false,"connected":false,"url":null}"#)
        #expect(status.enabled == false)
        #expect(status.connected == false)
        #expect(status.url == nil)
    }

    /// Charge réelle observée sur le Docker après activation (URL sans serveur Spoolman joignable).
    @Test("SpoolmanStatus décode l'état activé mais non connecté")
    func decodesEnabledNotConnected() throws {
        let status = try decode(
            SpoolmanStatus.self,
            #"{"enabled":true,"connected":false,"url":"http://127.0.0.1:7912"}"#
        )
        #expect(status.enabled == true)
        #expect(status.connected == false)
        #expect(status.url == "http://127.0.0.1:7912")
    }

    /// Charge réelle observée sur le Docker (`GET /settings/spoolman`) : booléens en chaînes.
    @Test("SpoolmanSettings décode les booléens en chaînes et expose des accesseurs typés")
    func decodesSettings() throws {
        let json = #"""
        {"spoolman_enabled":"true","spoolman_url":"http://127.0.0.1:7912",
        "spoolman_sync_mode":"auto","spoolman_disable_weight_sync":"false",
        "spoolman_report_partial_usage":"true"}
        """#
        let settings = try decode(SpoolmanSettings.self, json)
        #expect(settings.spoolmanUrl == "http://127.0.0.1:7912")
        #expect(settings.isEnabled == true)
        #expect(settings.isWeightSyncDisabled == false)
        #expect(settings.reportsPartialUsage == true)
        #expect(settings.spoolmanSyncMode == "auto")
    }

    @Test("SpoolmanSettingsUpdate encode les booléens en chaînes et omet les champs nil")
    func encodesUpdate() throws {
        let update = SpoolmanSettingsUpdate(spoolmanEnabled: true, spoolmanUrl: "http://host:7912")
        let data = try JSONEncoder.bambuddy().encode(update)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["spoolman_enabled"] as? String == "true")
        #expect(json["spoolman_url"] as? String == "http://host:7912")
        // Champs non fournis -> absents.
        #expect(json["spoolman_sync_mode"] == nil)
        #expect(json["spoolman_disable_weight_sync"] == nil)
    }
}
