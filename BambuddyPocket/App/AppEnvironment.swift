// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation

/// Composition root (DI maison, cf. ADR-0002) : assemble les dépendances de l'app —
/// persistance de la liste des serveurs, stockage Keychain des secrets, et fabrique de
/// connexion REST. Les écrans reçoivent ces collaborateurs via les view-models, jamais en global.
@MainActor
struct AppEnvironment {
    let serverStore: ServerStore
    let secretStore: SecretStore
    let connectionFactory: ServerConnectionFactory

    init(
        serverStore: ServerStore,
        secretStore: SecretStore,
        connectionFactory: ServerConnectionFactory
    ) {
        self.serverStore = serverStore
        self.secretStore = secretStore
        self.connectionFactory = connectionFactory
    }

    /// Environnement de production : secrets au Keychain, liste en `UserDefaults`.
    static func live() -> AppEnvironment {
        let secretStore = KeychainSecretStore()
        return AppEnvironment(
            serverStore: UserDefaultsServerStore(),
            secretStore: secretStore,
            connectionFactory: ServerConnectionFactory(secretStore: secretStore)
        )
    }

    /// Environnement en mémoire (previews & tests) : ni Keychain, ni persistance disque.
    static func inMemory(servers: [ServerConfiguration] = []) -> AppEnvironment {
        let secretStore = InMemorySecretStore()
        return AppEnvironment(
            serverStore: InMemoryServerStore(servers),
            secretStore: secretStore,
            connectionFactory: ServerConnectionFactory(secretStore: secretStore)
        )
    }
}
