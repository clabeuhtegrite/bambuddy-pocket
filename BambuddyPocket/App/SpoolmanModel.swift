// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de l'intégration Spoolman d'un serveur (`/spoolman/`, `/settings/spoolman`) : état,
/// réglages (activation, URL, mode de synchro), connexion/déconnexion.
@MainActor
@Observable
final class SpoolmanModel {
    private(set) var status: SpoolmanStatus?
    private(set) var settings: SpoolmanSettings?
    private(set) var hasLoaded = false
    private(set) var isBusy = false
    var loadError: String?
    var actionMessage: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    var isEnabled: Bool {
        status?.enabled ?? settings?.isEnabled ?? false
    }

    var isConnected: Bool {
        status?.connected ?? false
    }

    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            status = try await client.spoolmanStatus()
            settings = try await client.spoolmanSettings()
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Enregistre les réglages Spoolman puis recharge l'état.
    func save(_ update: SpoolmanSettingsUpdate) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            settings = try await client.updateSpoolmanSettings(update)
            await load()
            actionMessage = nil
            return true
        } catch {
            actionMessage = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Tente de se connecter au serveur Spoolman configuré puis recharge l'état.
    func connect() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.connectSpoolman()
            actionMessage = nil
            await load()
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }

    /// Se déconnecte du serveur Spoolman puis recharge l'état.
    func disconnect() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.disconnectSpoolman()
            actionMessage = nil
            await load()
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }
}
