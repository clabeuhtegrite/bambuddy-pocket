// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

@Suite("Présentation adaptative (Wi-Fi, AMS)")
struct PrinterPresentationTests {
    @Test("wifiSignal : qualité selon les seuils dBm")
    func wifiSignalQuality() {
        #expect(PrinterPresentation.wifiSignal(-29).contains("-29 dBm"))
        #expect(PrinterPresentation.wifiSignal(-29).contains(String(localized: "Excellent")))
        #expect(PrinterPresentation.wifiSignal(-55).contains(String(localized: "Good")))
        #expect(PrinterPresentation.wifiSignal(-65).contains(String(localized: "Fair")))
        #expect(PrinterPresentation.wifiSignal(-85).contains(String(localized: "Weak")))
    }

    @Test("AMSPresentation.title : libellé selon le type")
    func amsTitle() {
        #expect(AMSPresentation.title(kind: .standard, id: 0) == String(localized: "AMS 1"))
        #expect(AMSPresentation.title(kind: .amsLite, id: 0) == String(localized: "AMS Lite"))
        // L'AMS-HT (id matériel 128) est numérotée 1.
        #expect(AMSPresentation.title(kind: .ht, id: 128) == String(localized: "AMS-HT 1"))
    }

    @Test("activeExtruderLabel : index brut → buse numérotée + côté, jamais le chiffre seul")
    func activeExtruderLabel() {
        // Locale-agnostique : on vérifie la **structure** (numéro de buse 1-indexé + côté présent),
        // pas une chaîne traduite précise — le bundle de test ne résout pas toujours les mêmes
        // ressources que le bundle app.
        let left = PrinterPresentation.activeExtruderLabel(0)
        let right = PrinterPresentation.activeExtruderLabel(1)
        let third = PrinterPresentation.activeExtruderLabel(2)

        // Numérotation 1-indexée (l'index brut 0/1/2 → buse 1/2/3), jamais le chiffre brut seul.
        #expect(left.contains("1"))
        #expect(right.contains("2"))
        #expect(third.contains("3"))
        #expect(left != "1" && right != "2" && third != "3")

        // Côté présent pour les deux premières buses, dans n'importe quelle langue.
        let leftSides = ["left", "gauche", "izquierda", "links"]
        let rightSides = ["right", "droite", "derecha", "rechts"]
        #expect(leftSides.contains { left.lowercased().contains($0) })
        #expect(rightSides.contains { right.lowercased().contains($0) })
        // Au-delà : pas de côté (libellé numéroté simple).
        #expect(!rightSides.contains { third.lowercased().contains($0) })
    }
}
