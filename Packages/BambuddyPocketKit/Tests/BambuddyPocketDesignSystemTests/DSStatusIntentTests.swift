// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Testing
@testable import BambuddyPocketDesignSystem

@Suite("DSStatusIntent — mapping état → couleur sémantique")
struct DSStatusIntentTests {
    @Test("Impression active → accent")
    func runningIsAccent() {
        #expect(DSStatusIntent.forPrinterState(.running) == .accent)
        #expect(DSStatusIntent.forPrinterState(.prepare) == .accent)
    }

    @Test("Terminé → succès")
    func finishIsSuccess() {
        #expect(DSStatusIntent.forPrinterState(.finish) == .success)
    }

    @Test("Pause / découpe → avertissement")
    func pauseIsWarning() {
        #expect(DSStatusIntent.forPrinterState(.pause) == .warning)
        #expect(DSStatusIntent.forPrinterState(.slicing) == .warning)
    }

    @Test("Échec → erreur")
    func failedIsError() {
        #expect(DSStatusIntent.forPrinterState(.failed) == .error)
    }

    @Test("Inactif / inconnu / nil → neutre")
    func idleIsNeutral() {
        #expect(DSStatusIntent.forPrinterState(.idle) == .neutral)
        #expect(DSStatusIntent.forPrinterState(nil) == .neutral)
        #expect(DSStatusIntent.forPrinterState(.unknown("WAT")) == .neutral)
    }

    @Test("HMS fatal/serious → erreur, common → avertissement, info → accent")
    func hmsSeverityMapping() {
        #expect(DSStatusIntent.forHMSSeverity(.fatal) == .error)
        #expect(DSStatusIntent.forHMSSeverity(.serious) == .error)
        #expect(DSStatusIntent.forHMSSeverity(.common) == .warning)
        #expect(DSStatusIntent.forHMSSeverity(.info) == .accent)
        #expect(DSStatusIntent.forHMSSeverity(.unknown) == .neutral)
    }

    @Test("Drapeau succès → succès/erreur")
    func successFlagMapping() {
        #expect(DSStatusIntent.forSuccess(true) == .success)
        #expect(DSStatusIntent.forSuccess(false) == .error)
    }

    @Test("Chaque intention expose une couleur (toutes distinctes par sémantique)")
    func everyIntentHasColor() {
        for intent in DSStatusIntent.allCases {
            _ = intent.color
        }
        #expect(DSStatusIntent.allCases.count == 5)
    }
}
