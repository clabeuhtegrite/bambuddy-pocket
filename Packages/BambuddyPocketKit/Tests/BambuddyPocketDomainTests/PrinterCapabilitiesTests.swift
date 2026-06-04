// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
@testable import BambuddyPocketDomain

/// Table de référence (miroir de `printer_models.py`) : pour chaque modèle, les capacités attendues.
@Suite("PrinterModel / PrinterCapabilities (miroir printer_models.py)")
struct PrinterCapabilitiesTests {
    // MARK: Normalisation de modèle

    @Test("Noms 3MF → noms courts (PRINTER_MODEL_MAP)")
    func modelNameNormalization() {
        #expect(PrinterModel.fromModelName("Bambu Lab X1 Carbon")?.shortName == "X1C")
        #expect(PrinterModel.fromModelName("Bambu Lab A1 Mini")?.shortName == "A1 Mini")
        #expect(PrinterModel.fromModelName("Bambu Lab A1 mini")?.shortName == "A1 Mini")
        #expect(PrinterModel.fromModelName("Bambu Lab H2D Pro")?.shortName == "H2D Pro")
        #expect(PrinterModel.fromModelName("Bambu Lab X2D")?.shortName == "X2D")
    }

    @Test("Codes internes → noms courts (PRINTER_MODEL_ID_MAP)")
    func modelIDNormalization() {
        #expect(PrinterModel.fromModelID("C11")?.shortName == "X1C")
        #expect(PrinterModel.fromModelID("C13")?.shortName == "X1E")
        #expect(PrinterModel.fromModelID("N6")?.shortName == "X2D")
        #expect(PrinterModel.fromModelID("O1D")?.shortName == "H2D")
        #expect(PrinterModel.fromModelID("O1E")?.shortName == "H2D Pro")
        #expect(PrinterModel.fromModelID("O1C2")?.shortName == "H2C")
        #expect(PrinterModel.fromModelID("A04")?.shortName == "A1 Mini")
    }

    @Test("Modèle inconnu : préfixe Bambu Lab retiré, conservé tel quel")
    func unknownModelStripped() {
        #expect(PrinterModel.fromModelName("Bambu Lab Z9 Ultra")?.shortName == "Z9 Ultra")
        #expect(PrinterModel.fromModelID("ZZZ")?.shortName == "ZZZ")
        #expect(PrinterModel.fromModelName("") == nil)
        #expect(PrinterModel.fromModelName(nil) == nil)
        #expect(PrinterModel.fromModelName("   ") == nil)
    }

    @Test("resolve accepte nom 3MF, code interne ou nom court")
    func resolveTolerant() {
        #expect(PrinterModel.resolve("Bambu Lab X1 Carbon")?.shortName == "X1C")
        #expect(PrinterModel.resolve("O1D")?.shortName == "H2D")
        #expect(PrinterModel.resolve("X1C")?.shortName == "X1C")
        #expect(PrinterModel.resolve(nil) == nil)
        #expect(PrinterModel.resolve("  ") == nil)
    }

    @Test("Normalisation pour comparaison (upper, sans espace/tiret)")
    func normalizedForComparison() {
        #expect(PrinterModel(shortName: "A1 Mini").normalized == "A1MINI")
        #expect(PrinterModel(shortName: "H2D Pro").normalized == "H2DPRO")
        #expect(PrinterModel(shortName: " x1c ").normalized == "X1C")
        #expect(PrinterModel(shortName: "AMS-HT").normalized == "AMSHT")
    }

    // MARK: Table modèle → capacités

    /// Attendus dérivés directement des frozensets amont.
    struct Expectation {
        let dual: Bool
        let ethernet: Bool
        let rod: RodType?
        let heated: Bool
    }

    private func expect(_ short: String, _ exp: Expectation) {
        let caps = PrinterCapabilities.forModel(PrinterModel(shortName: short))
        #expect(caps.dualNozzle == exp.dual, "dualNozzle for \(short)")
        #expect(caps.hasEthernet == exp.ethernet, "hasEthernet for \(short)")
        #expect(caps.rodType == exp.rod, "rodType for \(short)")
        #expect(caps.heatedChamber == exp.heated, "heatedChamber for \(short)")
        #expect(caps.nozzleCount == (exp.dual ? 2 : 1), "nozzleCount for \(short)")
    }

    @Test("A1 / A1 Mini : mono, pas d'ethernet, rail linéaire, AMS Lite")
    func a1Series() {
        expect("A1", .init(dual: false, ethernet: false, rod: .linearRail, heated: false))
        expect("A1 Mini", .init(dual: false, ethernet: false, rod: .linearRail, heated: false))
        let caps = PrinterCapabilities.forModel(PrinterModel(shortName: "A1"))
        #expect(caps.amsKinds == [.amsLite])
    }

    @Test("X1 / X1C / X1E : mono, carbone ; ethernet seulement X1C/X1E")
    func x1Series() {
        expect("X1", .init(dual: false, ethernet: false, rod: .carbon, heated: false))
        expect("X1C", .init(dual: false, ethernet: true, rod: .carbon, heated: false))
        expect("X1E", .init(dual: false, ethernet: true, rod: .carbon, heated: false))
    }

    @Test("P1P / P1S / P2S : mono ; ethernet sauf P1P ; rod carbone (P1) ou acier (P2S)")
    func pSeries() {
        expect("P1P", .init(dual: false, ethernet: false, rod: .carbon, heated: false))
        expect("P1S", .init(dual: false, ethernet: true, rod: .carbon, heated: false))
        expect("P2S", .init(dual: false, ethernet: true, rod: .steelRod, heated: false))
    }

    @Test("H2D / H2D Pro / H2C : double buse, ethernet, rail linéaire")
    func h2DualSeries() {
        expect("H2D", .init(dual: true, ethernet: true, rod: .linearRail, heated: true))
        expect("H2D Pro", .init(dual: true, ethernet: true, rod: .linearRail, heated: true))
        expect("H2C", .init(dual: true, ethernet: true, rod: .linearRail, heated: false))
    }

    @Test("H2S : mono buse (pas dans DUAL_NOZZLE_MODELS), ethernet, rail linéaire")
    func h2sIsSingleNozzle() {
        expect("H2S", .init(dual: false, ethernet: true, rod: .linearRail, heated: false))
    }

    @Test("X2D : double buse, ethernet, tiges acier, chambre chauffée")
    func x2d() {
        expect("X2D", .init(dual: true, ethernet: true, rod: .steelRod, heated: true))
        let caps = PrinterCapabilities.forModel(PrinterModel(shortName: "X2D"))
        #expect(caps.amsKinds.contains(.ht))
        #expect(caps.amsKinds.contains(.standard))
    }

    @Test("Capacités cohérentes par codes internes (O1D, N6, C11…)")
    func capabilitiesViaInternalCodes() {
        #expect(PrinterCapabilities.forRawModel("O1D").dualNozzle) // H2D
        #expect(PrinterCapabilities.forRawModel("N6").dualNozzle) // X2D
        #expect(PrinterCapabilities.forRawModel("N6").rodType == .steelRod)
        #expect(!PrinterCapabilities.forRawModel("C11").dualNozzle) // X1C
        #expect(PrinterCapabilities.forRawModel("C11").hasEthernet)
    }

    // MARK: Dégradé sûr (modèle inconnu / futur)

    @Test("Modèle inconnu/futur → capacités prudentes, rien ne casse")
    func unknownModelSafeDefaults() {
        let caps = PrinterCapabilities.forModel(PrinterModel(shortName: "Z9 Ultra"))
        #expect(!caps.dualNozzle)
        #expect(!caps.hasEthernet)
        #expect(caps.rodType == nil)
        #expect(!caps.heatedChamber)
        #expect(caps.hasCamera) // permissif, confronté au statut réel
        #expect(caps.amsKinds == [.standard])
        #expect(caps.nozzleCount == 1)
    }

    @Test("Modèle nil → .unknown")
    func nilModelUnknown() {
        #expect(PrinterCapabilities.forModel(nil) == .unknown)
        #expect(PrinterCapabilities.forRawModel(nil) == .unknown)
        #expect(PrinterCapabilities.forRawModel("") == .unknown)
    }

    // MARK: Détection AMSKind depuis le statut

    @Test("AMSKind.detect : HT via is_ams_ht / module_type n3s")
    func detectHT() {
        #expect(AMSKind.detect(isAmsHt: true, moduleType: nil) == .ht)
        #expect(AMSKind.detect(isAmsHt: nil, moduleType: "n3s") == .ht)
        #expect(AMSKind.detect(isAmsHt: false, moduleType: "N3S") == .ht)
    }

    @Test("AMSKind.detect : Lite via module_type n3l ; sinon standard")
    func detectLiteAndStandard() {
        #expect(AMSKind.detect(isAmsHt: false, moduleType: "n3l") == .amsLite)
        #expect(AMSKind.detect(isAmsHt: false, moduleType: "n3f") == .standard)
        #expect(AMSKind.detect(isAmsHt: false, moduleType: "ams") == .standard)
        #expect(AMSKind.detect(isAmsHt: nil, moduleType: nil) == .standard)
    }

    @Test("AMSKind.detect : id ≥ 128 → HT (règle amont ams_id >= 128)")
    func detectHTByID() {
        #expect(AMSKind.detect(isAmsHt: nil, moduleType: nil, amsID: 128) == .ht)
        #expect(AMSKind.detect(isAmsHt: nil, moduleType: "ams", amsID: 130) == .ht)
        #expect(AMSKind.detect(isAmsHt: nil, moduleType: nil, amsID: 0) == .standard)
    }

    @Test("resolvedKind : standard sur modèle A1 (Lite seul) → amsLite")
    func resolvedKindLite() {
        var unit = AMSUnit(id: 0)
        unit.moduleType = "ams"
        #expect(unit.kind == .standard)
        #expect(unit.resolvedKind(modelOnlySupportsLite: true) == .amsLite)
        #expect(unit.resolvedKind(modelOnlySupportsLite: false) == .standard)
    }

    @Test("resolvedKind : une HT reste HT même si le modèle est Lite (détection statut prime)")
    func resolvedKindHTWins() {
        var unit = AMSUnit(id: 128)
        unit.isAmsHt = true
        #expect(unit.resolvedKind(modelOnlySupportsLite: true) == .ht)
    }

    @Test("Capacités AMS : A1 → Lite seul ; H2D/X2D → standard + HT")
    func amsCapabilityHelpers() {
        let a1 = PrinterCapabilities.forModel(PrinterModel(shortName: "A1"))
        #expect(a1.amsOnlyLite)
        #expect(!a1.supportsHeatedAMS)
        let x2d = PrinterCapabilities.forModel(PrinterModel(shortName: "X2D"))
        #expect(!x2d.amsOnlyLite)
        #expect(x2d.supportsHeatedAMS)
    }
}
