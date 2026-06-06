// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

/// Robustesse du décodage et cohérence des effets de bord (offline, null, vide, firmware ancien,
/// clés inconnues) sur **tous** les modèles. Le décodage ne doit **jamais** échouer.
@Suite("Robustesse PrinterStatus (effets de bord)")
struct PrinterStatusRobustnessTests {
    private func decode(_ json: String) throws -> PrinterStatus {
        try JSONDecoder.bambuddy().decode(PrinterStatus.self, from: Data(json.utf8))
    }

    // MARK: Champs null / absents / inconnus

    @Test("Champs explicitement null → nil, pas d'échec")
    func explicitNullsDecode() throws {
        let status = try decode(#"""
        {
          "name": "X1C", "model": "X1C", "connected": null, "state": null,
          "progress": null, "temperatures": null, "ams": null, "hms_errors": null,
          "wifi_signal": null, "firmware_version": null, "print_options": null
        }
        """#)
        #expect(status.name == "X1C")
        #expect(status.connected == nil)
        #expect(status.state == nil)
        #expect(status.temperatures == nil)
        #expect(status.ams == nil)
        #expect(!status.hasActiveErrors)
        #expect(!status.isPrinting)
        #expect(status.progressFraction == nil)
    }

    @Test("Clés inconnues (API future) ignorées sans échec")
    func unknownKeysIgnored() throws {
        let status = try decode(#"""
        {
          "model": "H2D", "state": "RUNNING", "progress": 50,
          "future_field": {"nested": [1, 2, 3]}, "another_unknown": "x",
          "temperatures": {"nozzle": 200, "quantum_flux": 42}
        }
        """#)
        #expect(status.state == .running)
        #expect(status.progress == 50)
        #expect(status.temperatures?.nozzle == 200)
    }

    @Test("Objet vide → toutes valeurs nil, helpers sûrs")
    func emptyObject() throws {
        let status = try decode("{}")
        #expect(status.name == nil)
        #expect(status.state == nil)
        #expect(!status.isPrinting)
        #expect(!status.hasActiveErrors)
        #expect(status.mostSevereError == nil)
        #expect(status.displayableStage == nil)
        #expect(status.statusCapabilities == .unknown)
        #expect(!status.showsSecondNozzle(capabilities: .unknown))
    }

    // MARK: AMS vide / partiel

    @Test("AMS vide (tableau []) → pas de crash, pas d'unité")
    func emptyAMSArray() throws {
        let status = try decode(#"{ "model": "X1C", "ams": [], "vt_tray": [] }"#)
        #expect(status.ams?.isEmpty == true)
        #expect(status.vtTray?.isEmpty == true)
    }

    @Test("Unité AMS sans plateaux ni champs → décode, kind par défaut standard")
    func amsUnitWithoutTrays() throws {
        let status = try decode(#"{ "ams": [ { "id": 0 } ] }"#)
        let unit = try #require(status.ams?.first)
        #expect(unit.tray == nil)
        #expect(unit.humidity == nil)
        #expect(unit.kind == .standard)
        #expect(!unit.isHeatedAMS)
    }

    @Test("Slots AMS tous vides (type null/vide) → kind détecté, slots conservés")
    func amsAllEmptySlots() throws {
        let status = try decode(#"""
        {
          "ams": [ { "id": 0, "module_type": "n3f", "tray": [
            { "id": 0, "tray_type": null, "remain": 0, "state": 9 },
            { "id": 1, "tray_type": "", "remain": 0, "state": 9 }
          ] } ]
        }
        """#)
        let unit = try #require(status.ams?.first)
        #expect(unit.tray?.count == 2)
        #expect(unit.kind == .standard)
        #expect(unit.tray?.allSatisfy { ($0.trayType ?? "").isEmpty } == true)
    }

    @Test("Unité AMS sans id → décode avec id par défaut 0, le reste du statut survit")
    func amsUnitMissingID() throws {
        let status = try decode(#"""
        {
          "name": "X1C", "state": "RUNNING", "progress": 40,
          "temperatures": { "nozzle": 220, "bed": 60 }, "chamber_light": true,
          "ams": [ { "humidity": 30, "tray": [ { "tray_type": "PLA" } ] } ]
        }
        """#)
        // Température/impression/lumière intactes malgré un AMS sans id.
        #expect(status.temperatures?.nozzle == 220)
        #expect(status.progress == 40)
        #expect(status.chamberLight == true)
        let unit = try #require(status.ams?.first)
        #expect(unit.id == 0)
        #expect(unit.humidity == 30)
        #expect(unit.tray?.first?.id == 0)
        #expect(unit.tray?.first?.trayType == "PLA")
    }

    @Test("AMS id en String ou null → toléré (retombe sur 0), pas d'échec global")
    func amsIDWrongType() throws {
        let status = try decode(#"""
        {
          "temperatures": { "nozzle": 200 },
          "ams": [
            { "id": "1", "tray": [ { "id": "0", "tray_type": "PLA" } ] },
            { "id": null }
          ]
        }
        """#)
        #expect(status.temperatures?.nozzle == 200)
        #expect(status.ams?.count == 2)
        #expect(status.ams?.first?.id == 1) // "1" toléré
        #expect(status.ams?.first?.tray?.first?.id == 0)
        #expect(status.ams?.last?.id == 0) // null → 0
    }

    @Test("Unité AMS structurellement invalide (scalaire) → ignorée, les bonnes survivent")
    func amsMalformedElementSkipped() throws {
        // Un élément non-objet dans `ams` ne doit pas effacer l'unité valide ni le reste du statut.
        let status = try decode(#"""
        {
          "name": "X1C", "state": "RUNNING",
          "temperatures": { "nozzle": 210 },
          "ams": [ 12345, { "id": 0, "humidity": 25 } ]
        }
        """#)
        #expect(status.temperatures?.nozzle == 210)
        #expect(status.state == .running)
        // Le scalaire est sauté ; l'unité valide est conservée.
        #expect(status.ams?.count == 1)
        #expect(status.ams?.first?.humidity == 25)
    }

    @Test("vt_tray malformé → plateaux valides conservés, statut intact")
    func vtTrayLossy() throws {
        let status = try decode(#"""
        {
          "temperatures": { "nozzle": 205 },
          "vt_tray": [ { "id": 254, "tray_type": "PETG" }, "garbage" ]
        }
        """#)
        #expect(status.temperatures?.nozzle == 205)
        #expect(status.vtTray?.count == 1)
        #expect(status.vtTray?.first?.trayType == "PETG")
    }

    // MARK: Firmware ancien (sous-ensemble de champs)

    @Test("Firmware ancien : seuls quelques champs présents → décode")
    func oldFirmwareSubset() throws {
        // Pas de print_options, pas d'airduct, pas de fans détaillés, pas de supports_drying.
        let status = try decode(#"""
        {
          "name": "P1P", "model": "P1P", "connected": true, "state": "RUNNING",
          "progress": 30, "layer_num": 10, "total_layers": 100,
          "temperatures": { "nozzle": 210, "bed": 60 },
          "ams": [ { "id": 0, "tray": [ { "id": 0, "tray_type": "PLA", "remain": 50 } ] } ]
        }
        """#)
        #expect(status.state == .running)
        #expect(status.printOptions == nil)
        #expect(status.airductMode == nil)
        #expect(status.coolingFanSpeed == nil)
        #expect(status.supportsDrying == nil)
        #expect(status.temperatures?.chamber == nil) // P1P sans chambre instrumentée ici
        let caps = PrinterCapabilities.forModel(status.statusModel)
        #expect(!caps.hasEthernet) // P1P n'a pas d'ethernet
        #expect(caps.rodType == .carbon)
    }

    // MARK: Effets de bord — fusion offline

    @Test("Delta offline efface l'activité d'affichage (étape résiduelle masquée)")
    func offlineMergeHidesStage() throws {
        var running = try decode(#"{ "connected": true, "state": "RUNNING", "stg_cur_name": "Printing" }"#)
        #expect(running.displayableStage == "Printing")
        let offlineDelta = try decode(#"{ "connected": false, "state": "IDLE" }"#)
        running = running.merged(with: offlineDelta)
        #expect(running.connected == false)
        #expect(running.state == .idle)
        #expect(running.displayableStage == nil) // plus d'impression active
    }

    @Test("Fusion : la 2ᵉ buse (nozzle_2) est conservée via le remplacement de temperatures")
    func mergePreservesSecondNozzle() throws {
        let base = try decode(#"{ "temperatures": { "nozzle": 200, "nozzle_2": 205 } }"#)
        // Un delta sans temperatures conserve l'objet courant.
        let delta = try decode(#"{ "progress": 10 }"#)
        let merged = base.merged(with: delta)
        #expect(merged.temperatures?.nozzle2 == 205)
        #expect(merged.progress == 10)
        // Un delta avec temperatures remplace tout l'objet (sémantique documentée).
        let delta2 = try decode(#"{ "temperatures": { "nozzle": 210 } }"#)
        let merged2 = base.merged(with: delta2)
        #expect(merged2.temperatures?.nozzle == 210)
        #expect(merged2.temperatures?.nozzle2 == nil)
    }

    // MARK: Types numériques tolérants

    @Test("Entiers et flottants : progress et températures acceptent l'un ou l'autre")
    func numericTolerance() throws {
        let intForm = try decode(#"{ "progress": 42, "temperatures": { "nozzle": 200, "bed": 60 } }"#)
        #expect(intForm.progress == 42)
        #expect(intForm.temperatures?.nozzle == 200)
        let floatForm = try decode(#"{ "progress": 42.7, "remaining_time": 90 }"#)
        #expect((floatForm.progressFraction ?? 0) > 0.42)
    }

    // MARK: Fixtures de bord

    @Test("Fixture offline minimale (P1S déconnectée, champs null)")
    func decodesOfflineFixture() throws {
        let url = try #require(
            Bundle.module.url(forResource: "offline_minimal_status", withExtension: "json")
        )
        let status = try JSONDecoder.bambuddy().decode(PrinterStatus.self, from: Data(contentsOf: url))
        #expect(status.connected == false)
        #expect(status.temperatures == nil)
        #expect(status.ams == nil)
        // Étape résiduelle masquée car non en impression active.
        #expect(status.displayableStage == nil)
        // Capacités P1S correctement déduites malgré l'absence de données de statut.
        let caps = PrinterCapabilities.forModel(status.statusModel)
        #expect(caps.hasEthernet)
        #expect(!caps.dualNozzle)
        #expect(caps.rodType == .carbon)
    }

    // MARK: Maintenance — capacités/rails dérivés du modèle (tolérant)

    private func decodeMaintenance(_ json: String) throws -> MaintenanceOverview {
        try JSONDecoder.bambuddy().decode(MaintenanceOverview.self, from: Data(json.utf8))
    }

    @Test("Maintenance : rodType dérivé du modèle connu (X2D → acier)")
    func maintenanceRodTypeKnownModel() throws {
        let overview = try decodeMaintenance(#"""
        { "printer_id": 7, "printer_name": "X2D", "printer_model": "X2D" }
        """#)
        #expect(overview.rodType == .steelRod)
        #expect(overview.capabilities.dualNozzle)
    }

    @Test("Maintenance : modèle inconnu → rodType nil, capacités prudentes")
    func maintenanceRodTypeUnknownModel() throws {
        let overview = try decodeMaintenance(#"""
        { "printer_id": 8, "printer_name": "Futur", "printer_model": "ZZ9-Plural-Z-Alpha" }
        """#)
        #expect(overview.rodType == nil)
        #expect(overview.capabilities == .unknown)
    }

    @Test("Maintenance : champ printer_model absent → rodType nil, .unknown")
    func maintenanceRodTypeMissingModel() throws {
        let overview = try decodeMaintenance(#"{ "printer_id": 9, "maintenance_items": [] }"#)
        #expect(overview.printerModel == nil)
        #expect(overview.rodType == nil)
        #expect(overview.capabilities == .unknown)
    }
}
