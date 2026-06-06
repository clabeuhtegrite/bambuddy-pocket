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

    /// Environnement de production : secrets au Keychain, liste en `UserDefaults`.
    ///
    /// En **mode démo** (`-uitest-demo`, captures marketing uniquement) la fabrique de connexion
    /// utilise une `URLSession` instrumentée qui sert des fixtures locales (`DemoURLProtocol`) :
    /// aucun trafic réseau réel, aucune imprimante touchée. Sans effet en build normal.
    static func live() -> AppEnvironment {
        let secretStore = KeychainSecretStore()
        let session: URLSession = DemoMode.isEnabled ? DemoMode.makeSession() : .shared
        return AppEnvironment(
            serverStore: UserDefaultsServerStore(),
            secretStore: secretStore,
            connectionFactory: ServerConnectionFactory(secretStore: secretStore, session: session)
        )
    }

    /// Environnement en mémoire (previews & tests) : ni Keychain, ni persistance disque.
    /// `session` permet d'injecter une `URLSession` mockée (tests réseau).
    static func inMemory(
        servers: [ServerConfiguration] = [],
        session: URLSession = .shared
    ) -> AppEnvironment {
        let secretStore = InMemorySecretStore()
        return AppEnvironment(
            serverStore: InMemoryServerStore(servers),
            secretStore: secretStore,
            connectionFactory: ServerConnectionFactory(secretStore: secretStore, session: session)
        )
    }
}
