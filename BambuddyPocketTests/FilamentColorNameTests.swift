// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
@testable import BamPocket

@Suite("Noms de couleur filament (bucketing HSL, #8)")
struct FilamentColorNameTests {
    // Familles attendues, comparées via la même clé localisée que l'implémentation pour rester
    // indépendantes de la locale du runner (on valide le **bucketing**, pas la traduction).
    private let red = String(localized: "color.red")
    private let green = String(localized: "color.green")
    private let blue = String(localized: "color.blue")
    private let yellow = String(localized: "color.yellow")
    private let cyan = String(localized: "color.cyan")
    private let purple = String(localized: "color.purple")
    private let pink = String(localized: "color.pink")
    private let black = String(localized: "color.black")
    private let white = String(localized: "color.white")
    private let gray = String(localized: "color.gray")
    private let darkGray = String(localized: "color.darkGray")
    private let lightGray = String(localized: "color.lightGray")
    private let brown = String(localized: "color.brown")

    @Test("from(hex:) : nil pour un hex inexploitable (vide, court, transparent)")
    func fromRejectsUnusable() {
        #expect(FilamentColorName.from(hex: nil) == nil)
        #expect(FilamentColorName.from(hex: "") == nil)
        #expect(FilamentColorName.from(hex: "FFF") == nil)
        // Entièrement transparent (alpha 00) → pas de couleur exploitable.
        #expect(FilamentColorName.from(hex: "FF000000") == nil)
    }

    @Test("from(hex:) : tolère le préfixe # et l'alpha opaque")
    func fromAcceptsHashAndAlpha() {
        #expect(FilamentColorName.from(hex: "#FF0000") == red)
        #expect(FilamentColorName.from(hex: "FF0000FF") == red)
    }

    @Test("from(hex:) : familles primaires/secondaires bucketées comme l'amont")
    func fromBucketsPrimaries() {
        #expect(FilamentColorName.from(hex: "FF0000") == red)
        #expect(FilamentColorName.from(hex: "00FF00") == green)
        #expect(FilamentColorName.from(hex: "0000FF") == blue)
        #expect(FilamentColorName.from(hex: "FFFF00") == yellow)
        #expect(FilamentColorName.from(hex: "00FFFF") == cyan)
        // Violet vrai (teinte ~270) vs magenta (teinte 300 → rose), comme l'amont.
        #expect(FilamentColorName.from(hex: "8000FF") == purple)
        #expect(FilamentColorName.from(hex: "FF00FF") == pink)
    }

    @Test("from(hex:) : neutres par luminosité (noir, blanc, gris)")
    func fromBucketsNeutrals() {
        #expect(FilamentColorName.from(hex: "000000") == black)
        #expect(FilamentColorName.from(hex: "FFFFFF") == white)
        #expect(FilamentColorName.from(hex: "808080") == gray)
        #expect(FilamentColorName.from(hex: "404040") == darkGray)
        #expect(FilamentColorName.from(hex: "C0C0C0") == lightGray)
    }

    @Test("from(hex:) : brun (teinte orange/jaune à faible luminosité)")
    func fromBucketsBrown() {
        #expect(FilamentColorName.from(hex: "5C3A1E") == brown)
    }

    @Test("isBambuColorCode : détecte les codes internes (A06-D0) et épargne les noms lisibles")
    func detectsBambuCodes() {
        #expect(FilamentColorName.isBambuColorCode("A06-D0"))
        #expect(FilamentColorName.isBambuColorCode("X12-Y3"))
        #expect(!FilamentColorName.isBambuColorCode("Galaxy Black"))
        #expect(!FilamentColorName.isBambuColorCode("Red"))
    }

    @Test("resolved : nom lisible prioritaire, repli HSL pour un code interne")
    func resolvedPrefersReadableName() {
        // Nom lisible stocké → conservé tel quel.
        #expect(FilamentColorName.resolved(colorName: "Galaxy Black", hex: "FF0000") == "Galaxy Black")
        // Code interne ignoré → repli sur le hex.
        #expect(FilamentColorName.resolved(colorName: "A06-D0", hex: "FF0000") == red)
        // Aucun nom → repli sur le hex.
        #expect(FilamentColorName.resolved(colorName: nil, hex: "0000FF") == blue)
        // Aucun nom ni hex exploitable → nil.
        #expect(FilamentColorName.resolved(colorName: nil, hex: nil) == nil)
    }
}
