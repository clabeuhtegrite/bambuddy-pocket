// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("Secrets & InMemorySecretStore")
struct SecretsTests {
    @Test("ServerSecrets.isEmpty")
    func emptyDetection() {
        #expect(ServerSecrets().isEmpty)
        #expect(ServerSecrets(apiKey: "x").isEmpty == false)
        #expect(ServerSecrets(cloudflareClientID: "id").isEmpty == false)
    }

    @Test("Stockage en mémoire : set / get / delete")
    func setGetDelete() throws {
        let store = InMemorySecretStore()
        let id = UUID()
        #expect(try store.secrets(for: id).isEmpty)

        try store.setSecrets(ServerSecrets(apiKey: "bb_key", cloudflareClientID: "cf"), for: id)
        let loaded = try store.secrets(for: id)
        #expect(loaded.apiKey == "bb_key")
        #expect(loaded.cloudflareClientID == "cf")

        try store.deleteSecrets(for: id)
        #expect(try store.secrets(for: id).isEmpty)
    }

    @Test("Enregistrer des secrets vides revient à les supprimer")
    func emptyClears() throws {
        let store = InMemorySecretStore()
        let id = UUID()
        try store.setSecrets(ServerSecrets(apiKey: "k"), for: id)
        try store.setSecrets(ServerSecrets(), for: id)
        #expect(try store.secrets(for: id).isEmpty)
    }
}
