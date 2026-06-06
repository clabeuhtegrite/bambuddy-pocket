// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

/// `URLProtocol` minimal pour mocker les réponses REST du flux de connexion (réponses par chemin,
/// query ignorée ; compteur d'appels par chemin pour vérifier l'envoi du mail 2FA).
private final class LoginStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var responses: [String: (Int, Data)] = [:]
    nonisolated(unsafe) static var hits: [String: Int] = [:]

    static func reset() {
        responses = [:]
        hits = [:]
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    private static func normalize(_ path: String) -> String {
        path.hasSuffix("/") && path.count > 1 ? String(path.dropLast()) : path
    }

    override func startLoading() {
        let path = Self.normalize(request.url?.path ?? "")
        Self.hits[path, default: 0] += 1
        let match = Self.responses.first { Self.normalize($0.key) == path }?.value
        let (status, data) = match ?? (404, Data())
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func loginStubSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [LoginStubURLProtocol.self]
    return URLSession(configuration: config)
}

/// Tests du **retour device A4** : un compte en 2FA **email** doit déclencher l'envoi du mail (et
/// non se comporter comme du TOTP), adopter le `pre_auth_token` frais, et libeller le prompt.
@MainActor
@Suite("Flux de connexion 2FA", .serialized)
struct LoginModelTests {
    private func makeModel(session: URLSession) throws -> LoginModel {
        let environment = AppEnvironment.inMemory(session: session)
        let url = try #require(URL(string: "http://host:8000"))
        let configuration = ServerConfiguration(label: "", baseURL: url, authMethod: .userPassword)
        let client = environment.connectionFactory.makeClient(for: configuration, secrets: ServerSecrets())
        return LoginModel(client: client)
    }

    /// 2FA email seule : la soumission des identifiants déclenche `POST /auth/2fa/email/send`,
    /// adopte le jeton frais, et marque la méthode `email` (prompt « code reçu par email »).
    @Test("Un compte 2FA email envoie le mail et passe en méthode email")
    func emailTwoFactorSendsMail() async throws {
        LoginStubURLProtocol.reset()
        defer { LoginStubURLProtocol.reset() }
        LoginStubURLProtocol.responses["/api/v1/auth/login"] = (
            200,
            Data(#"{"requires_2fa":true,"pre_auth_token":"pre-1","two_fa_methods":["email"]}"#.utf8)
        )
        LoginStubURLProtocol.responses["/api/v1/auth/2fa/email/send"] = (
            200,
            Data(#"{"message":"sent","pre_auth_token":"pre-2"}"#.utf8)
        )

        let model = try makeModel(session: loginStubSession())
        model.username = "ad"
        model.password = "pw"
        await model.submit()

        #expect(model.step == .twoFactor)
        #expect(model.isEmailOTP == true)
        #expect(model.error == nil)
        #expect(LoginStubURLProtocol.hits["/api/v1/auth/2fa/email/send"] == 1)
    }

    /// 2FA TOTP : aucun mail n'est envoyé (l'app d'authentification fournit le code), méthode TOTP.
    @Test("Un compte TOTP n'envoie pas de mail")
    func totpTwoFactorDoesNotSendMail() async throws {
        LoginStubURLProtocol.reset()
        defer { LoginStubURLProtocol.reset() }
        LoginStubURLProtocol.responses["/api/v1/auth/login"] = (
            200,
            Data(#"{"requires_2fa":true,"pre_auth_token":"pre-1","two_fa_methods":["totp","backup"]}"#.utf8)
        )

        let model = try makeModel(session: loginStubSession())
        model.username = "ad"
        model.password = "pw"
        await model.submit()

        #expect(model.step == .twoFactor)
        #expect(model.isEmailOTP == false)
        #expect(LoginStubURLProtocol.hits["/api/v1/auth/2fa/email/send"] == nil)
    }

    /// Le renvoi de code rappelle `POST /auth/2fa/email/send` et adopte de nouveau le jeton frais.
    @Test("Renvoyer le code rappelle /auth/2fa/email/send")
    func resendCallsSendAgain() async throws {
        LoginStubURLProtocol.reset()
        defer { LoginStubURLProtocol.reset() }
        LoginStubURLProtocol.responses["/api/v1/auth/login"] = (
            200,
            Data(#"{"requires_2fa":true,"pre_auth_token":"pre-1","two_fa_methods":["email"]}"#.utf8)
        )
        LoginStubURLProtocol.responses["/api/v1/auth/2fa/email/send"] = (
            200,
            Data(#"{"message":"sent","pre_auth_token":"pre-2"}"#.utf8)
        )

        let model = try makeModel(session: loginStubSession())
        model.username = "ad"
        model.password = "pw"
        await model.submit()
        await model.resendEmailCode()

        #expect(LoginStubURLProtocol.hits["/api/v1/auth/2fa/email/send"] == 2)
    }
}
