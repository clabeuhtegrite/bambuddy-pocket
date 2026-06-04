// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de la maintenance d'un serveur : vue d'ensemble par imprimante + « marquer effectué ».
@MainActor
@Observable
final class MaintenanceModel {
    private(set) var overview: [MaintenanceOverview] = []
    private(set) var hasLoaded = false
    /// Identifiants des items dont l'action « effectué » est en cours.
    private(set) var busy: Set<Int> = []
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
            overview = try await client.maintenanceOverview()
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Marque un élément comme effectué puis met à jour son état dans la vue d'ensemble.
    func markPerformed(_ item: MaintenanceItem) async {
        busy.insert(item.id)
        defer { busy.remove(item.id) }
        do {
            let client = try connectionFactory.makeClient(for: server)
            let updated = try await client.performMaintenance(itemID: item.id)
            apply(updated)
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    private func apply(_ updated: MaintenanceItem) {
        for printerIndex in overview.indices {
            guard var items = overview[printerIndex].maintenanceItems,
                  let itemIndex = items.firstIndex(where: { $0.id == updated.id })
            else {
                continue
            }
            items[itemIndex] = updated
            overview[printerIndex].maintenanceItems = items
        }
    }
}
