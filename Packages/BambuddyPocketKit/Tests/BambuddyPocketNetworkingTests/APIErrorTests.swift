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

    @Test("isNotFound ne vaut true que pour un HTTP 404 (fonction non disponible)")
    func isNotFoundOnlyFor404() {
        #expect(APIError.http(status: 404, body: nil).isNotFound)
        #expect(!APIError.http(status: 500, body: nil).isNotFound)
        #expect(!APIError.unauthorized.isNotFound)
        #expect(!APIError.forbidden(reason: "nope").isNotFound)
    }

    @Test("isConflict ne vaut true que pour un HTTP 409 (état désiré déjà atteint)")
    func isConflictOnlyFor409() {
        #expect(APIError.http(status: 409, body: nil).isConflict)
        #expect(!APIError.http(status: 404, body: nil).isConflict)
        #expect(!APIError.http(status: 500, body: nil).isConflict)
        #expect(!APIError.unauthorized.isConflict)
        #expect(!APIError.forbidden(reason: "nope").isConflict)
    }

    @Test("isForbidden ne vaut true que pour un 403 (fonction admin réservée)")
    func isForbiddenOnlyFor403() {
        #expect(APIError.forbidden(reason: nil).isForbidden)
        #expect(APIError.forbidden(reason: "admin only").isForbidden)
        #expect(!APIError.unauthorized.isForbidden)
        #expect(!APIError.http(status: 403, body: nil).isForbidden)
    }

    @Test("forbidden distingue le motif serveur dans l'égalité")
    func forbiddenEquatableByReason() {
        #expect(APIError.forbidden(reason: "a") == APIError.forbidden(reason: "a"))
        #expect(APIError.forbidden(reason: "a") != APIError.forbidden(reason: "b"))
        #expect(APIError.forbidden(reason: nil) != APIError.unauthorized)
    }
}
