// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de l'inventaire des bobines de filament d'un serveur (lecture, REST).
@MainActor
@Observable
final class InventoryListModel {
    private(set) var spools: [Spool] = []
    private(set) var hasLoaded = false
    var loadError: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            spools = try await client.inventorySpools()
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Récupère l'historique de consommation d'une bobine (`[]` en cas d'échec).
    func usage(for spool: Spool) async -> [SpoolUsage] {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.spoolUsage(id: spool.id)
        } catch {
            return []
        }
    }

    /// Applique une édition de bobine et met à jour l'élément en place.
    func update(_ spool: Spool, with edit: SpoolUpdate) async {
        await mutate { try await $0.updateSpool(id: spool.id, edit) }
    }

    /// Remet à zéro le compteur de consommation affiché de la bobine.
    func resetUsage(_ spool: Spool) async {
        await mutate { try await $0.resetSpoolUsage(id: spool.id) }
    }

    /// Supprime une bobine du serveur puis la retire de la liste.
    func delete(_ spool: Spool) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteSpool(id: spool.id)
            spools.removeAll { $0.id == spool.id }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    private func mutate(_ action: (RESTClient) async throws -> Spool) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let updated = try await action(client)
            if let index = spools.firstIndex(where: { $0.id == updated.id }) {
                spools[index] = updated
            }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }
}
