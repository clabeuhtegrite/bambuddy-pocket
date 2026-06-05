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
      "hms_errors": [ { "code": "0700_4001_0002_0001", "attr": 117441024, "module": 7, "severity": 2 } ],
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
        #expect(status.mostSevereError?.code == "0700_4001_0002_0001")
        #expect(status.mostSevereError?.shortCode == "0700_4001")
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

    // MARK: Étape affichable (displayableStage)

    @Test("L'étape résiduelle est masquée quand l'imprimante est inactive (IDLE + stg_cur_name)")
    func hidesResidualStageWhenIdle() throws {
        let status = try decode(
            PrinterStatus.self,
            #"{ "connected": true, "state": "IDLE", "stg_cur_name": "Printing" }"#
        )
        #expect(status.stgCurName == "Printing")
        #expect(status.displayableStage == nil)
    }

    @Test("L'étape est affichée pendant une impression active")
    func showsStageWhilePrinting() throws {
        let running = try decode(
            PrinterStatus.self,
            #"{ "state": "RUNNING", "stg_cur_name": "Heating bed" }"#
        )
        #expect(running.displayableStage == "Heating bed")

        let paused = try decode(
            PrinterStatus.self,
            #"{ "state": "PAUSE", "stg_cur_name": "Paused by user" }"#
        )
        #expect(paused.displayableStage == "Paused by user")
    }

    @Test("Une étape vide ou absente ne s'affiche pas même en impression")
    func hidesEmptyStage() throws {
        let empty = try decode(
            PrinterStatus.self,
            #"{ "state": "RUNNING", "stg_cur_name": "" }"#
        )
        #expect(empty.displayableStage == nil)

        let missing = try decode(PrinterStatus.self, #"{ "state": "RUNNING" }"#)
        #expect(missing.displayableStage == nil)
    }

    @Test("Aucune étape pour les états terminés ou inconnus")
    func hidesStageForFinishedOrUnknown() throws {
        let finished = try decode(
            PrinterStatus.self,
            #"{ "state": "FINISH", "stg_cur_name": "Printing" }"#
        )
        #expect(finished.displayableStage == nil)

        let offline = try decode(
            PrinterStatus.self,
            #"{ "connected": false, "stg_cur_name": "Printing" }"#
        )
        #expect(offline.displayableStage == nil)
    }

    // MARK: Régression matériel réel (X2D)

    /// Charge la charge JSON **réellement capturée** sur une X2D physique (anonymisée : numéros de
    /// série / UID / UUID / nom de tâche neutralisés ; structure et valeurs métier préservées).
    private func realX2DStatus() throws -> PrinterStatus {
        let url = try #require(
            Bundle.module.url(forResource: "x2d_real_status", withExtension: "json"),
            "Fixture x2d_real_status.json introuvable"
        )
        let data = try Data(contentsOf: url)
        return try JSONDecoder.bambuddy().decode(PrinterStatus.self, from: data)
    }

    @Test("Décode le statut réel d'une X2D (3 AMS dont AMS-HT, double extrudeur, FAILED)")
    func decodesRealX2DStatus() throws {
        let status = try realX2DStatus()
        #expect(status.state == .failed)
        #expect(status.connected == true)
        // Double extrudeur : l'extrudeur actif et la chambre sont rapportés.
        #expect(status.activeExtruder == 1)
        #expect(status.temperatures?.nozzle == 27.0)
        #expect(status.temperatures?.bed == 26.0)
        #expect(status.temperatures?.chamber == 26.0)
        // Trois unités AMS, dont une AMS-HT (id 128).
        #expect(status.ams?.count == 3)
        let amsHT = try #require(status.ams?.first { $0.id == 128 })
        #expect(amsHT.isAmsHt == true)
        #expect(amsHT.humidity == 42)
        #expect(amsHT.moduleType == "n3s")
        // Ventilateurs présents (tous à 0 ici, mais décodés).
        #expect(status.coolingFanSpeed == 0)
        #expect(status.heatbreakFanSpeed == 0)
        // Options d'impression réelles.
        #expect(status.printOptions?.spaghettiDetector == true)
        #expect(status.printOptions?.haltPrintSensitivity == "medium")
        #expect(status.airductMode == 0)
        #expect(status.supportsDrying == true)
    }

    @Test("Types d'AMS de la fixture X2D : deux standard (n3f) + une HT (n3s, id 128)")
    func amsKindsFromRealX2D() throws {
        let status = try realX2DStatus()
        let units = try #require(status.ams)
        let standard = units.filter { $0.kind == .standard }
        let ht = units.filter { $0.kind == .ht }
        #expect(standard.count == 2)
        #expect(ht.count == 1)
        let htUnit = try #require(ht.first)
        #expect(htUnit.id == 128)
        #expect(htUnit.isHeatedAMS)
        // X2D supporte standard + HT, pas Lite seul → résolution inchangée.
        let caps = PrinterCapabilities.forModel(PrinterModel(shortName: "X2D"))
        #expect(htUnit.resolvedKind(modelOnlySupportsLite: caps.amsOnlyLite) == .ht)
    }

    @Test("Fixture A1 (AMS Lite) : unité standard côté statut, résolue Lite par le modèle")
    func decodesA1AMSLite() throws {
        let url = try #require(
            Bundle.module.url(forResource: "a1_ams_lite_status", withExtension: "json")
        )
        let status = try JSONDecoder.bambuddy().decode(PrinterStatus.self, from: Data(contentsOf: url))
        #expect(status.statusModel?.shortName == "A1 Mini")
        let caps = PrinterCapabilities.forModel(status.statusModel)
        #expect(caps.amsOnlyLite)
        // Pas de chambre, pas d'ethernet, mono-buse.
        #expect(!caps.dualNozzle)
        #expect(!caps.hasEthernet)
        #expect(status.temperatures?.chamber == nil)
        let unit = try #require(status.ams?.first)
        #expect(unit.kind == .standard) // module_type "ams"
        #expect(unit.resolvedKind(modelOnlySupportsLite: caps.amsOnlyLite) == .amsLite)
        #expect(unit.humidity == nil) // AMS Lite ouverte : pas d'humidité
        // Slots : 2 chargés, 2 vides (type nil ou "").
        #expect(unit.tray?.count == 4)
        #expect(status.supportsDrying == false)
    }

    @Test("Une gravité HMS réelle hors plage 1…3 (6) retombe sur .info (pas .unknown)")
    func realHMSSeverityFallsBackToInfo() throws {
        let status = try realX2DStatus()
        // La X2D réelle a renvoyé deux erreurs HMS : severity (brut) 6 et 2.
        #expect(status.hmsErrors?.count == 2)
        let severities = (status.hmsErrors ?? []).compactMap(\.severity).sorted()
        #expect(severities == [2, 6])
        let sev6 = try #require(status.hmsErrors?.first { $0.severity == 6 })
        #expect(sev6.severityLevel == .info)
        let sev2 = try #require(status.hmsErrors?.first { $0.severity == 2 })
        // Le champ brut `severity:2` se lit `.serious`…
        #expect(sev2.severityLevel == .serious)
        // …mais la **gravité effective** dérive du quartet `(attr >> 8) & 0xF` (sémantique réelle
        // X2D) : pour `0x30027` (attr 0x05030000) ce quartet vaut 0 → `.info`, donc non alarmant.
        #expect(sev2.effectiveSeverity == .info)
        #expect(sev2.isAlarming == false)
    }

    @Test("Les deux HMS réels X2D sont informatifs/de statut : aucune alarme")
    func realHMSAreNonAlarming() throws {
        let status = try realX2DStatus()
        // Les codes 0x20070 (sev 6) et 0x30027 (sev 2) sont des messages info/statut que la X2D
        // émet en continu : ni l'un ni l'autre ne doit alarmer ni faire surface comme erreur.
        #expect(status.alarmingErrors.isEmpty)
        #expect(status.hasActiveErrors == false)
        #expect(status.mostSevereError == nil)
    }

    @Test("Filtrage par catalogue connu (parité web UI) : les codes X2D réels sont *inconnus* donc masqués")
    func knownCodeFilterMatchesWebUI() throws {
        let status = try realX2DStatus()
        // La web UI (`filterKnownHMSErrors`) ne surface qu'un code présent dans `ERROR_DESCRIPTIONS`.
        // Les deux codes réels de la X2D (`0500_0070`, `0503_0027`) en sont absents → masqués.
        for error in status.hmsErrors ?? [] {
            #expect(error.isKnown == false)
            #expect(error.isAlarming == false)
        }
        // Un code *connu et grave* (0700_4001, quartet de gravité 2) doit, lui, alarmer.
        let known = HMSError(code: "0x4001", attr: 0x0700_0200)
        #expect(known.isKnown)
        #expect(known.isAlarming)
        // Un code *connu mais informatif* (quartet 0) ne doit pas alarmer.
        let knownInfo = HMSError(code: "0x4001", attr: 0x0700_0000)
        #expect(knownInfo.isKnown)
        #expect(knownInfo.isAlarming == false)
    }

    @Test("Code court canonique MMMM_CCCC + libellé humain pour le HMS réel 0x30027")
    func realHMSShortCodeAndLabel() throws {
        let status = try realX2DStatus()
        let error = try #require(status.hmsErrors?.first { $0.code == "0x30027" })
        // attr 0x05030000 → module 0x0503, code&0xFFFF = 0x0027.
        #expect(error.shortCode == "0503_0027")
        #expect(error.displayCode == "HMS 0503_0027")
        // Code inconnu de la table : pas de raison connue, mais un libellé lisible (jamais 0x… brut).
        #expect(error.failureReasonKey == nil)
        #expect(error.displayCode.contains("0x") == false)
    }

    @Test("HMSSeverity : 0 et toute valeur ≥ 4 → .info (forward-compat)")
    func hmsSeverityForwardCompat() {
        #expect(HMSSeverity(code: 1) == .fatal)
        #expect(HMSSeverity(code: 2) == .serious)
        #expect(HMSSeverity(code: 3) == .common)
        #expect(HMSSeverity(code: 4) == .info)
        #expect(HMSSeverity(code: 0) == .info)
        #expect(HMSSeverity(code: 6) == .info)
        #expect(HMSSeverity(code: 15) == .info)
    }

    // MARK: Double extrudeur

    @Test("Décode la seconde buse (nozzle_2) de la fixture X2D réelle")
    func decodesSecondNozzleFromRealX2D() throws {
        let status = try realX2DStatus()
        #expect(status.temperatures?.nozzle == 27.0)
        #expect(status.temperatures?.nozzle2 == 27.0)
        #expect(status.temperatures?.nozzle2Target == 0.0)
        #expect(status.activeExtruder == 1)
        // Le statut expose les données de seconde buse, indépendamment du modèle.
        #expect(status.statusReportsSecondNozzle)
        // Avec les capacités X2D (double extrudeur), l'UI affiche la seconde buse.
        let x2dCaps = PrinterCapabilities.forModel(PrinterModel(shortName: "X2D"))
        #expect(status.showsSecondNozzle(capabilities: x2dCaps))
    }

    @Test("Mono-buse : pas de seconde buse, showsSecondNozzle == false")
    func singleNozzleHasNoSecondNozzle() throws {
        let status = try decode(
            PrinterStatus.self,
            #"{ "temperatures": { "nozzle": 210.0, "nozzle_target": 220.0 } }"#
        )
        #expect(status.temperatures?.nozzle2 == nil)
        #expect(!status.statusReportsSecondNozzle)
        let x1cCaps = PrinterCapabilities.forModel(PrinterModel(shortName: "X1C"))
        #expect(!status.showsSecondNozzle(capabilities: x1cCaps))
    }

    @Test("Modèle dual mais firmware sans données de seconde buse : rien d'erroné")
    func dualModelWithoutSecondNozzleData() throws {
        let status = try decode(PrinterStatus.self, #"{ "temperatures": { "nozzle": 50.0 } }"#)
        let x2dCaps = PrinterCapabilities.forModel(PrinterModel(shortName: "X2D"))
        // Pas de nozzle_2 ni d'active_extruder → on n'affiche pas la 2ᵉ buse.
        #expect(!status.showsSecondNozzle(capabilities: x2dCaps))
    }

    @Test("Statut sans modèle : capacités dégradées, pas de crash")
    func missingModelDegradesSafely() throws {
        let status = try decode(PrinterStatus.self, #"{ "state": "IDLE" }"#)
        #expect(status.statusModel == nil)
        #expect(status.statusCapabilities == .unknown)
        #expect(!status.showsSecondNozzle(capabilities: .unknown))
    }

    @Test("Décode les options d'impression (xcam) et le mode du conduit d'air")
    func decodesPrintOptionsAndAirduct() throws {
        let status = try decode(
            PrinterStatus.self,
            #"""
            {"airduct_mode":1,
             "print_options":{"spaghetti_detector":true,"first_layer_inspector":false,
               "allow_skip_parts":true,"halt_print_sensitivity":"high"}}
            """#
        )
        #expect(status.airductMode == 1)
        #expect(status.printOptions?.spaghettiDetector == true)
        #expect(status.printOptions?.firstLayerInspector == false)
        #expect(status.printOptions?.allowSkipParts == true)
        #expect(status.printOptions?.haltPrintSensitivity == "high")
    }
}
