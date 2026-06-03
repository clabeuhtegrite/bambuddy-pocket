// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("App smoke")
struct AppSmokeTests {
    @Test("Le domaine est lié et fonctionnel depuis la cible app")
    func domainLinked() throws {
        let url = try #require(URL(string: "http://192.168.0.10:8000"))
        let server = ServerConfiguration(label: "Test", baseURL: url)
        #expect(server.webSocketURL?.absoluteString == "ws://192.168.0.10:8000/api/v1/ws")
    }
}
