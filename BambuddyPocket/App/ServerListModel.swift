// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// État d'un test de connexion vers un serveur.
enum ConnectionTestState: Equatable {
    case idle
    case testing
    case success(AuthStatus)
    case failure(String)
}

/// View-model de la gestion multi-serveurs (liste, ajout/édition, suppression, test de
/// connexion). `@MainActor` : toutes les mutations d'état se font sur le thread principal.
@MainActor
@Observable
final class ServerListModel {
    private(set) var servers: [ServerConfiguration] = []
    /// Dernière erreur de chargement/persistance, à afficher le cas échéant.
    var lastError: String?

    private let serverStore: ServerStore
    private let secretStore: SecretStore
    private let connectionFactory: ServerConnectionFactory

    init(environment: AppEnvironment) {
        serverStore = environment.serverStore
        secretStore = environment.secretStore
        connectionFactory = environment.connectionFactory
    }

    /// Charge la liste persistée. À appeler à l'apparition de l'écran.
    func reload() {
        do {
            servers = try serverStore.load()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Crée ou met à jour un serveur et ses secrets, puis persiste la liste.
    func save(_ configuration: ServerConfiguration, secrets: ServerSecrets) throws {
        try secretStore.setSecrets(secrets, for: configuration.id)
        if let index = servers.firstIndex(where: { $0.id == configuration.id }) {
            servers[index] = configuration
        } else {
            servers.append(configuration)
        }
        try serverStore.save(servers)
    }

    /// Secrets actuellement stockés pour ce serveur (vide si absent ou erreur Keychain).
    func secrets(for configuration: ServerConfiguration) -> ServerSecrets {
        (try? secretStore.secrets(for: configuration.id)) ?? ServerSecrets()
    }

    /// Construit le view-model des imprimantes (REST + temps réel) pour ce serveur.
    func makePrinterListModel(for configuration: ServerConfiguration) -> PrinterListModel {
        PrinterListModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model de l'archive d'impressions pour ce serveur.
    func makeArchiveListModel(for configuration: ServerConfiguration) -> ArchiveListModel {
        ArchiveListModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model de la file d'attente pour ce serveur.
    func makeQueueListModel(for configuration: ServerConfiguration) -> QueueListModel {
        QueueListModel(server: configuration, connectionFactory: connectionFactory)
    }

    func delete(_ configuration: ServerConfiguration) throws {
        servers.removeAll { $0.id == configuration.id }
        try serverStore.save(servers)
        try secretStore.deleteSecrets(for: configuration.id)
    }

    func delete(at offsets: IndexSet) throws {
        let removed = offsets.map { servers[$0] }
        servers.remove(atOffsets: offsets)
        try serverStore.save(servers)
        for server in removed {
            try secretStore.deleteSecrets(for: server.id)
        }
    }

    /// Teste la connexion via `GET /auth/status` (léger, ne requiert pas d'auth).
    func testConnection(_ configuration: ServerConfiguration) async -> ConnectionTestState {
        do {
            let status = try await connectionFactory.probe(configuration)
            return .success(status)
        } catch let error as APIError {
            return .failure(Self.message(for: error))
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .invalidURL:
            String(localized: "The server URL is not valid.")
        case .unauthorized:
            String(localized: "Unauthorized — check your credentials.")
        case let .transport(message):
            message
        case let .http(status, _):
            String(localized: "The server returned an unexpected status (\(status)).")
        case .decoding:
            String(localized: "The server response could not be read.")
        case let .server(message):
            message
        }
    }
}
