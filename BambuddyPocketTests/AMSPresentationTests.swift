// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// Tests de la **numérotation lisible des unités AMS** (B2). Les AMS-HT ont des id matériels qui
/// commencent à 128 ; on doit présenter un numéro 1-based (offset 128), tandis que les AMS standard
/// sont simplement décalées de +1 et l'AMS Lite n'est pas numérotée.
@Suite("Numérotation des unités AMS")
struct AMSPresentationTests {
    @Test("L'AMS-HT applique l'offset 128 pour un numéro lisible 1-based")
    func htAppliesOffset128() {
        #expect(AMSPresentation.title(kind: .ht, id: 128).contains("1"))
        #expect(AMSPresentation.title(kind: .ht, id: 129).contains("2"))
        #expect(AMSPresentation.title(kind: .ht, id: 131).contains("4"))
    }

    @Test("L'AMS-HT ne réutilise pas l'id matériel brut dans le libellé")
    func htDoesNotLeakRawHardwareID() {
        // id 128 → « AMS-HT 1 » : le 128 brut ne doit pas apparaître.
        #expect(!AMSPresentation.title(kind: .ht, id: 128).contains("128"))
        #expect(!AMSPresentation.title(kind: .ht, id: 129).contains("129"))
    }

    @Test("L'AMS standard est numérotée à partir de 1 (id + 1)")
    func standardIsOneBased() {
        #expect(AMSPresentation.title(kind: .standard, id: 0).contains("1"))
        #expect(AMSPresentation.title(kind: .standard, id: 3).contains("4"))
    }

    @Test("L'AMS Lite n'est pas numérotée")
    func amsLiteHasNoNumber() {
        let title = AMSPresentation.title(kind: .amsLite, id: 0)
        #expect(!title.contains("0"))
        #expect(!title.contains("1"))
    }
}
