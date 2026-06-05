// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

/// `PrinterStatus.liveState` doit refléter l'état **vivant de la machine** (statut de connexion) et
/// non le *résultat du dernier print*. Un `FAILED` résiduel sur une imprimante connectée et au repos
/// ne doit pas se présenter comme un échec de connexion (le faux badge rouge « Échec » du bug).
@Suite("PrinterStatus · liveState")
struct PrinterLiveStateTests {
    private func status(state: PrinterState?, connected: Bool?) -> PrinterStatus {
        var s = PrinterStatus()
        s.state = state
        s.connected = connected
        return s
    }

    @Test("FAILED résiduel + connectée + au repos → déclassé en .idle (pas d'« Échec »)")
    func residualFailedWhileConnectedBecomesIdle() {
        #expect(status(state: .failed, connected: true).liveState == .idle)
    }

    @Test("FAILED + connected nil (statut WS partiel) → toujours déclassé en .idle")
    func residualFailedWithUnknownConnectionBecomesIdle() {
        // `connected` est souvent absent des deltas WebSocket ; on ne traite comme « hors ligne »
        // que `connected == false`, donc un nil ne doit pas raviver le faux « Échec ».
        #expect(status(state: .failed, connected: nil).liveState == .idle)
    }

    @Test("FAILED mais imprimante déconnectée → état inchangé (le badge Hors ligne prime en amont)")
    func failedWhileOfflineUnchanged() {
        #expect(status(state: .failed, connected: false).liveState == .failed)
    }

    @Test("Impression active (RUNNING/PREPARE/PAUSE) → état inchangé")
    func activePrintStatesUnchanged() {
        #expect(status(state: .running, connected: true).liveState == .running)
        #expect(status(state: .prepare, connected: true).liveState == .prepare)
        #expect(status(state: .pause, connected: true).liveState == .pause)
    }

    @Test("FINISH n'est pas déclassé (un « Terminé » vert reste exact et neutre)")
    func finishStateUnchanged() {
        #expect(status(state: .finish, connected: true).liveState == .finish)
    }

    @Test("Les états non terminaux passent tels quels")
    func passthroughStates() {
        #expect(status(state: .idle, connected: true).liveState == .idle)
        #expect(status(state: nil, connected: true).liveState == nil)
        #expect(status(state: .unknown("CUSTOM"), connected: true).liveState == .unknown("CUSTOM"))
    }
}
