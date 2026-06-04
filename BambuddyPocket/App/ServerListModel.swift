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
    /// Centres de notifications persistants, mis en cache par serveur (session WebSocket vivante).
    private var notificationCenters: [ServerConfiguration.ID: ServerNotificationCenter] = [:]

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

    /// Centre de notifications **persistant** du serveur (session WebSocket vivante tant que le
    /// serveur est sélectionné). Mis en cache : un seul flux et un seul feed par serveur, partagés
    /// entre tous les écrans. Démarre le flux à la première demande.
    func notificationCenter(for configuration: ServerConfiguration) -> ServerNotificationCenter {
        if let existing = notificationCenters[configuration.id] {
            return existing
        }
        let center = ServerNotificationCenter(
            server: configuration,
            connectionFactory: connectionFactory
        )
        center.start()
        notificationCenters[configuration.id] = center
        return center
    }

    /// Construit le view-model des imprimantes (REST + temps réel partagé) pour ce serveur.
    func makePrinterListModel(for configuration: ServerConfiguration) -> PrinterListModel {
        PrinterListModel(
            server: configuration,
            connectionFactory: connectionFactory,
            notificationCenter: notificationCenter(for: configuration)
        )
    }

    /// Construit le view-model de l'archive d'impressions pour ce serveur.
    func makeArchiveListModel(for configuration: ServerConfiguration) -> ArchiveListModel {
        ArchiveListModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model de la file d'attente pour ce serveur.
    func makeQueueListModel(for configuration: ServerConfiguration) -> QueueListModel {
        QueueListModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model du flux d'activité pour ce serveur.
    func makeActivityListModel(for configuration: ServerConfiguration) -> ActivityListModel {
        ActivityListModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model de l'inventaire des bobines pour ce serveur.
    func makeInventoryListModel(for configuration: ServerConfiguration) -> InventoryListModel {
        InventoryListModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model de la bibliothèque de modèles pour ce serveur.
    func makeLibraryListModel(for configuration: ServerConfiguration) -> LibraryListModel {
        LibraryListModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model des projets pour ce serveur.
    func makeProjectListModel(for configuration: ServerConfiguration) -> ProjectListModel {
        ProjectListModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model des réglages serveur pour ce serveur.
    func makeSettingsModel(for configuration: ServerConfiguration) -> SettingsModel {
        SettingsModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model de l'état serveur (système/santé) pour ce serveur.
    func makeSystemStatusModel(for configuration: ServerConfiguration) -> SystemStatusModel {
        SystemStatusModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model des clés d'API pour ce serveur.
    func makeAPIKeysModel(for configuration: ServerConfiguration) -> APIKeysModel {
        APIKeysModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model du profil/compte pour ce serveur.
    func makeAccountModel(for configuration: ServerConfiguration) -> AccountModel {
        AccountModel(server: configuration, connectionFactory: connectionFactory, serverList: self)
    }

    /// Construit le view-model des prises connectées pour ce serveur.
    func makeSmartPlugsModel(for configuration: ServerConfiguration) -> SmartPlugsModel {
        SmartPlugsModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model de la maintenance pour ce serveur.
    func makeMaintenanceModel(for configuration: ServerConfiguration) -> MaintenanceModel {
        MaintenanceModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model des mises à jour firmware pour ce serveur.
    func makeFirmwareModel(for configuration: ServerConfiguration) -> FirmwareModel {
        FirmwareModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model du catalogue de filaments pour ce serveur.
    func makeFilamentCatalogModel(for configuration: ServerConfiguration) -> FilamentCatalogModel {
        FilamentCatalogModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model des liens externes pour ce serveur.
    func makeExternalLinksModel(for configuration: ServerConfiguration) -> ExternalLinksModel {
        ExternalLinksModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model des sauvegardes locales pour ce serveur.
    func makeBackupsModel(for configuration: ServerConfiguration) -> BackupsModel {
        BackupsModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Construit le view-model de la découverte réseau pour ce serveur.
    func makeDiscoveryModel(for configuration: ServerConfiguration) -> DiscoveryModel {
        DiscoveryModel(server: configuration, connectionFactory: connectionFactory)
    }

    /// Efface le JWT (`bearerToken`) stocké pour ce serveur après une déconnexion.
    func clearBearerToken(for configuration: ServerConfiguration) {
        var secrets = secrets(for: configuration)
        guard secrets.bearerToken != nil else {
            return
        }
        secrets.bearerToken = nil
        try? secretStore.setSecrets(secrets, for: configuration.id)
    }

    /// Construit un `LoginModel` pour se connecter à un serveur **non encore enregistré**
    /// (identifié par son URL et ses éventuels secrets Cloudflare).
    func makeLoginModel(baseURL: URL, secrets: ServerSecrets, usesCloudflare: Bool) -> LoginModel {
        let configuration = ServerConfiguration(
            label: "",
            baseURL: baseURL,
            authMethod: .userPassword,
            usesCloudflareAccess: usesCloudflare
        )
        let client = connectionFactory.makeClient(for: configuration, secrets: secrets)
        return LoginModel(client: client)
    }

    func delete(_ configuration: ServerConfiguration) throws {
        servers.removeAll { $0.id == configuration.id }
        try serverStore.save(servers)
        try secretStore.deleteSecrets(for: configuration.id)
        stopNotificationCenter(for: configuration.id)
    }

    func delete(at offsets: IndexSet) throws {
        let removed = offsets.map { servers[$0] }
        servers.remove(atOffsets: offsets)
        try serverStore.save(servers)
        for server in removed {
            try secretStore.deleteSecrets(for: server.id)
            stopNotificationCenter(for: server.id)
        }
    }

    private func stopNotificationCenter(for id: ServerConfiguration.ID) {
        notificationCenters.removeValue(forKey: id)?.stop()
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
