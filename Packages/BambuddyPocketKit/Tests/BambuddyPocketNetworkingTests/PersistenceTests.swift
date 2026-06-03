// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation
import Testing
@testable import BambuddyPocketNetworking

@Suite("Persistance & mapping d'autorisation")
struct PersistenceTests {
    @Test("UserDefaultsServerStore : round-trip de la liste")
    func serverStoreRoundTrip() throws {
        let suite = "test-\(UUID().uuidString)"
        // swiftlint:disable:next force_unwrapping
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = UserDefaultsServerStore(defaults: defaults)
        #expect(try store.load().isEmpty)

        // swiftlint:disable:next force_unwrapping
        let url = try #require(URL(string: "https://printers.example.com"))
        let servers = [
            ServerConfiguration(label: "Atelier", baseURL: url, authMethod: .apiKey, usesCloudflareAccess: true)
        ]
        try store.save(servers)
        let loaded = try store.load()
        #expect(loaded == servers)
    }

    @Test("RequestAuthorization : méthode .apiKey → X-API-Key seulement")
    func authApiKey() {
        let secrets = ServerSecrets(apiKey: "bb_key", bearerToken: "jwt")
        let auth = RequestAuthorization(secrets: secrets, authMethod: .apiKey, usesCloudflareAccess: false)
        #expect(auth.apiKey == "bb_key")
        #expect(auth.bearerToken == nil)
        #expect(auth.cloudflareClientID == nil)
    }

    @Test("RequestAuthorization : méthode .userPassword → Bearer seulement")
    func authBearer() {
        let secrets = ServerSecrets(apiKey: "bb_key", bearerToken: "jwt")
        let auth = RequestAuthorization(secrets: secrets, authMethod: .userPassword, usesCloudflareAccess: false)
        #expect(auth.bearerToken == "jwt")
        #expect(auth.apiKey == nil)
    }

    @Test("RequestAuthorization : Cloudflare ajouté seulement si activé")
    func cloudflareToggle() {
        let secrets = ServerSecrets(cloudflareClientID: "cf-id", cloudflareClientSecret: "cf-secret")
        let off = RequestAuthorization(secrets: secrets, authMethod: .none, usesCloudflareAccess: false)
        #expect(off.cloudflareClientID == nil)
        let on = RequestAuthorization(secrets: secrets, authMethod: .none, usesCloudflareAccess: true)
        #expect(on.cloudflareClientID == "cf-id")
        #expect(on.cloudflareClientSecret == "cf-secret")
    }
}
