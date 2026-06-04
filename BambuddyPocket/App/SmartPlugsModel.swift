// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model des prises connectées d'un serveur : liste, état temps réel, pilotage on/off.
@MainActor
@Observable
final class SmartPlugsModel {
    private(set) var plugs: [SmartPlug] = []
    /// État temps réel par identifiant de prise (chargé à la demande).
    private(set) var statuses: [Int: SmartPlugStatus] = [:]
    private(set) var hasLoaded = false
    /// Identifiants des prises dont une commande est en cours.
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
            plugs = try await client.smartPlugs()
            loadError = nil
            await refreshStatuses()
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Recharge l'état temps réel de chaque prise (échecs individuels ignorés).
    func refreshStatuses() async {
        guard let client = try? connectionFactory.makeClient(for: server) else {
            return
        }
        for plug in plugs {
            if let status = try? await client.smartPlugStatus(id: plug.id) {
                statuses[plug.id] = status
            }
        }
    }

    /// Pilote une prise puis rafraîchit son état.
    func control(_ plug: SmartPlug, action: SmartPlugAction) async {
        busy.insert(plug.id)
        defer { busy.remove(plug.id) }
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.controlSmartPlug(id: plug.id, action: action)
            statuses[plug.id] = try? await client.smartPlugStatus(id: plug.id)
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }
}
