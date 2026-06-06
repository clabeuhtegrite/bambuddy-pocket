// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketNetworking

@Suite("Session réseau dédiée")
struct ServerConnectionFactorySessionTests {
    @Test("La configuration dédiée borne le timeout de requête à 15 s")
    func requestTimeoutIsBounded() {
        let configuration = ServerConnectionFactory.liveSessionConfiguration()
        #expect(configuration.timeoutIntervalForRequest == 15)
    }

    @Test("La configuration dédiée attend la connectivité")
    func waitsForConnectivity() {
        let configuration = ServerConnectionFactory.liveSessionConfiguration()
        #expect(configuration.waitsForConnectivity)
    }

    @Test("Le timeout ressource reste au défaut pour ne pas plafonner un flux long")
    func resourceTimeoutKeptDefault() {
        let configuration = ServerConnectionFactory.liveSessionConfiguration()
        // Défaut système : 7 jours. On vérifie simplement qu'on ne l'a pas raccourci.
        #expect(configuration.timeoutIntervalForResource >= 60 * 60)
    }
}
