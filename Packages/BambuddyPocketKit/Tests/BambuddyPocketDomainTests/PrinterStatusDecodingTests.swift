// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("Décodage PrinterStatus / Printer")
struct PrinterStatusDecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.bambuddy().decode(type, from: Data(json.utf8))
    }

    private static let fullStatusJSON = #"""
    {
      "name": "X1C Atelier",
      "model": "X1C",
      "connected": true,
      "state": "RUNNING",
      "current_print": "benchy.3mf",
      "subtask_name": "Benchy",
      "gcode_file": "/data/Metadata/plate_1.gcode",
      "progress": 42.5,
      "remaining_time": 87,
      "layer_num": 120,
      "total_layers": 300,
      "cover_url": "/api/v1/printers/1/cover",
      "current_archive_id": 7,
      "temperatures": { "nozzle": 220.0, "nozzle_target": 220.0, "bed": 60.0, "bed_target": 60.0, "chamber": 32.0, "chamber_target": 0.0 },
      "hms_errors": [ { "code": "0300_0100_0002_0001", "attr": 50348039, "module": 3, "severity": 2 } ],
      "ams": [ { "id": 0, "humidity": 25, "temp": 28.0, "is_ams_ht": false, "dry_time": 0,
        "tray": [ { "id": 0, "tray_color": "FF6A13FF", "tray_type": "PLA", "remain": 78,
                    "nozzle_temp_min": 190, "nozzle_temp_max": 230, "state": 0 } ] } ],
      "vt_tray": [],
      "wifi_signal": -47,
      "door_open": false,
      "chamber_light": true,
      "speed_level": 2,
      "cooling_fan_speed": 80,
      "firmware_version": "01.08.00.00",
      "supports_drying": true
    }
    """#

    @Test("Décode un statut complet et ses objets imbriqués")
    func decodesFullStatus() throws {
        let status = try decode(PrinterStatus.self, Self.fullStatusJSON)
        #expect(status.name == "X1C Atelier")
        #expect(status.state == .running)
        #expect(status.isPrinting)
        #expect(status.progress == 42.5)
        #expect((status.progressFraction ?? 0) > 0.42 && (status.progressFraction ?? 0) < 0.43)
        #expect(status.remainingTime == 87)
        #expect(status.coverUrl == "/api/v1/printers/1/cover")
        #expect(status.wifiSignal == -47)
        #expect(status.temperatures?.nozzleTarget == 220)
        #expect(status.temperatures?.bed == 60)
    }

    @Test("Décode l'AMS et ses plateaux")
    func decodesAMS() throws {
        let status = try decode(PrinterStatus.self, Self.fullStatusJSON)
        let tray = try #require(status.ams?.first?.tray?.first)
        #expect(status.ams?.first?.humidity == 25)
        #expect(status.ams?.first?.isAmsHt == false)
        #expect(tray.trayType == "PLA")
        #expect(tray.remain == 78)
        #expect(tray.trayColor == "FF6A13FF")
    }

    @Test("Décode les erreurs HMS et calcule la gravité")
    func decodesHMS() throws {
        let status = try decode(PrinterStatus.self, Self.fullStatusJSON)
        #expect(status.hasActiveErrors)
        #expect(status.hmsErrors?.count == 1)
        #expect(status.mostSevereError?.severityLevel == .serious)
        #expect(status.mostSevereError?.code == "0300_0100_0002_0001")
    }

    @Test("Un état inconnu retombe sur .unknown (forward-compat)")
    func unknownStateFallback() throws {
        let state = try JSONDecoder().decode(PrinterState.self, from: Data("\"CALIBRATING\"".utf8))
        #expect(state == .unknown("CALIBRATING"))
        #expect(state.apiValue == "CALIBRATING")
    }

    @Test("Un payload WebSocket partiel décode (champs absents -> nil)")
    func decodesPartialWebSocketPayload() throws {
        let status = try decode(
            PrinterStatus.self,
            #"{ "connected": true, "state": "PAUSE", "progress": 99.9, "layer_num": 299 }"#
        )
        #expect(status.connected == true)
        #expect(status.state == .pause)
        #expect(status.progress == 99.9)
        #expect(status.temperatures == nil)
        #expect(status.ams == nil)
        #expect(status.name == nil)
    }

    @Test("Printer décode sans exposer access_code (ignoré)")
    func decodesPrinterWithoutSecret() throws {
        let json = #"""
        { "id": 1, "name": "X1C", "serial_number": "01ABCDEF", "ip_address": "192.168.1.50",
          "access_code": "12345678", "model": "X1C", "is_active": true, "nozzle_count": 1,
          "created_at": "2026-06-01T10:00:00Z", "updated_at": "2026-06-02T10:00:00Z" }
        """#
        let printer = try decode(Printer.self, json)
        #expect(printer.id == 1)
        #expect(printer.name == "X1C")
        #expect(printer.ipAddress == "192.168.1.50")
        #expect(printer.serialNumber == "01ABCDEF")
        #expect(printer.isActive == true)
    }
}
