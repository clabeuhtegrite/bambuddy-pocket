// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("VirtualPrinter")
struct VirtualPrinterTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.bambuddy().decode(type, from: Data(json.utf8))
    }

    /// Charge réelle observée sur le Docker (`GET /virtual-printers`).
    @Test("VirtualPrinterList décode la charge réelle (printers + table des modèles)")
    func decodesRealList() throws {
        let json = #"""
        {"printers":[{"id":1,"name":"VP-Test","enabled":true,"mode":"immediate","model":"BL-P001",
        "model_name":"X1C","access_code_set":true,"serial":"00M00A391800001","target_printer_id":null,
        "auto_dispatch":true,"queue_force_color_match":false,"bind_ip":"127.0.0.1",
        "remote_interface_ip":null,"tailscale_disabled":true,"position":1,
        "status":{"running":true,"pending_files":0}}],
        "models":{"BL-P001":"X1C","C11":"P1P"}}
        """#
        let list = try decode(VirtualPrinterList.self, json)
        #expect(list.models["BL-P001"] == "X1C")
        #expect(list.models["C11"] == "P1P")
        let vp = try #require(list.printers.first)
        #expect(vp.id == 1)
        #expect(vp.name == "VP-Test")
        #expect(vp.enabled == true)
        #expect(vp.mode == "immediate")
        #expect(vp.modelName == "X1C")
        #expect(vp.accessCodeSet == true)
        #expect(vp.serial == "00M00A391800001")
        #expect(vp.bindIp == "127.0.0.1")
        #expect(vp.autoDispatch == true)
        #expect(vp.isRunning == true)
        #expect(vp.status?.pendingFiles == 0)
    }

    /// Charge réelle observée sur le Docker après `POST` (VP désactivée).
    @Test("VirtualPrinter décode un détail créé")
    func decodesCreated() throws {
        let json = #"""
        {"id":2,"name":"VP-DevTest","enabled":false,"mode":"immediate","model":"C11",
        "model_name":"P1P","access_code_set":false,"serial":"01S00A391800002","target_printer_id":null,
        "auto_dispatch":true,"queue_force_color_match":false,"bind_ip":null,"remote_interface_ip":null,
        "tailscale_disabled":true,"position":2,"status":{"running":false,"pending_files":0}}
        """#
        let vp = try decode(VirtualPrinter.self, json)
        #expect(vp.id == 2)
        #expect(vp.enabled == false)
        #expect(vp.model == "C11")
        #expect(vp.accessCodeSet == false)
        #expect(vp.bindIp == nil)
        #expect(vp.isRunning == false)
    }

    @Test("VirtualPrinterCreate encode les clés en snake_case")
    func encodesCreate() throws {
        let create = VirtualPrinterCreate(name: "Dev", model: "C11", accessCode: "12345678", autoDispatch: false)
        let data = try JSONEncoder.bambuddy().encode(create)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["name"] as? String == "Dev")
        #expect(json["access_code"] as? String == "12345678")
        #expect(json["auto_dispatch"] as? Bool == false)
        #expect(json["queue_force_color_match"] as? Bool == false)
    }

    @Test("VirtualPrinterUpdate n'encode que les champs renseignés")
    func encodesPartialUpdate() throws {
        let update = VirtualPrinterUpdate(name: "Renamed", autoDispatch: false)
        let data = try JSONEncoder.bambuddy().encode(update)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["name"] as? String == "Renamed")
        #expect(json["auto_dispatch"] as? Bool == false)
        #expect(json["enabled"] == nil)
        #expect(json["mode"] == nil)
    }
}
