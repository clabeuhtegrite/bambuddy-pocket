// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("SmartPlug")
struct SmartPlugTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.bambuddy().decode(type, from: Data(json.utf8))
    }

    @Test("SmartPlugStatus interprète l'état on/off")
    func interpretsState() throws {
        let on = try decode(SmartPlugStatus.self, #"{"state":"on","reachable":true}"#)
        #expect(on.isOn == true)
        #expect(on.isReachable)

        let off = try decode(SmartPlugStatus.self, #"{"state":"OFF","reachable":true}"#)
        #expect(off.isOn == false)

        let unknown = try decode(SmartPlugStatus.self, #"{"state":"weird","reachable":false}"#)
        #expect(unknown.isOn == nil)
        #expect(unknown.isReachable == false)

        let missing = try decode(SmartPlugStatus.self, #"{"reachable":true}"#)
        #expect(missing.isOn == nil)
    }

    @Test("SmartPlugControl encode l'action en snake/lower")
    func encodesControl() throws {
        let data = try JSONEncoder.bambuddy().encode(SmartPlugControl(action: .toggle))
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"toggle\""))
    }

    @Test("SmartPlug décode printer_id et enabled par défaut")
    func decodesPlug() throws {
        let plug = try decode(SmartPlug.self, #"{"id":5,"name":"P","plug_type":"tasmota"}"#)
        #expect(plug.id == 5)
        #expect(plug.isEnabled == true)
        #expect(plug.printerID == nil)
    }
}
