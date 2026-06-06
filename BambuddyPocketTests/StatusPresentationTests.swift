// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
@testable import BamPocket

@Suite("Statuts — libellés localisés")
struct StatusPresentationTests {
    @Test("Statuts connus → libellé non brut (différent de la valeur capitalisée crue)")
    func knownStatusesAreMapped() {
        // En locale par défaut (en) le libellé reste lisible ; on vérifie surtout que les variantes
        // d'écriture (casse, synonymes) convergent vers le même libellé canonique.
        #expect(StatusPresentation.label("completed") == StatusPresentation.label("SUCCESS"))
        #expect(StatusPresentation.label("printing") == StatusPresentation.label("RUNNING"))
        #expect(StatusPresentation.label("waiting") == StatusPresentation.label("queued"))
        #expect(StatusPresentation.label("cancelled") == StatusPresentation.label("canceled"))
    }

    @Test("Statut inconnu → repli capitalisé")
    func unknownStatusFallsBack() {
        #expect(StatusPresentation.label("teleporting") == "Teleporting")
        #expect(StatusPresentation.label("foo bar") == "Foo Bar")
    }

    @Test("Statuts distincts → libellés distincts")
    func distinctStatusesDiffer() {
        #expect(StatusPresentation.label("completed") != StatusPresentation.label("failed"))
        #expect(StatusPresentation.label("printing") != StatusPresentation.label("waiting"))
        #expect(StatusPresentation.label("scheduled") != StatusPresentation.label("paused"))
    }
}
