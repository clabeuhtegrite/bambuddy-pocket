// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
@testable import BambuddyPocketNetworking

@Suite("Networking primitives")
struct APIErrorTests {
    @Test("Les erreurs HTTP se comparent par statut")
    func httpErrorsCompareByStatus() {
        #expect(APIError.http(status: 404, body: nil) == APIError.http(status: 404, body: nil))
        #expect(APIError.http(status: 404, body: nil) != APIError.http(status: 500, body: nil))
    }

    @Test("Les valeurs brutes des méthodes HTTP sont correctes")
    func methodRawValues() {
        #expect(HTTPMethod.get.rawValue == "GET")
        #expect(HTTPMethod.delete.rawValue == "DELETE")
    }
}
