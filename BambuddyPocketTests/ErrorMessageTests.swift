// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Testing
@testable import BamPocket

@Suite("ErrorMessage")
struct ErrorMessageTests {
    /// Un 403 (ex. clé d'API sur une fonction d'administration : clés d'API, sauvegardes) ne doit
    /// **pas** produire le même message qu'un 401 « identifiants » : il oriente vers une connexion
    /// par compte (admin), et ne suggère pas à tort des identifiants erronés.
    @Test("403 ≠ 401 : message « admin requis » distinct, sans « identifiants »")
    func forbiddenDiffersFromUnauthorized() {
        let unauthorized = ErrorMessage.text(for: APIError.unauthorized)
        let forbidden = ErrorMessage.text(for: APIError.forbidden(
            reason: "API keys cannot be used for administrative operations"
        ))
        #expect(forbidden != unauthorized)
        // Le message 403 oriente vers une connexion par compte/identifiants (admin).
        #expect(
            forbidden.localizedCaseInsensitiveContains("admin")
                || forbidden.localizedCaseInsensitiveContains("account")
                || forbidden.localizedCaseInsensitiveContains("identifiant")
                || forbidden.localizedCaseInsensitiveContains("password")
        )
    }

    /// Un 404 signifie « fonction non disponible sur ce serveur » et non « erreur serveur ».
    @Test("404 → message « non disponible », distinct des autres statuts")
    func notFoundHasDedicatedMessage() {
        let notFound = ErrorMessage.text(for: APIError.http(status: 404, body: nil))
        let generic = ErrorMessage.text(for: APIError.http(status: 500, body: nil))
        #expect(notFound != generic)
        // Le message 500 mentionne le statut numérique ; celui de 404 ne doit pas le faire.
        #expect(generic.contains("500"))
        #expect(!notFound.contains("404"))
    }
}
