// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de la gestion des imprimantes virtuelles d'un serveur (`/virtual-printers`) :
/// émulateurs de périphériques Bambu, utiles au développement et aux tests. CRUD complet.
@MainActor
@Observable
final class VirtualPrintersModel {
    private(set) var printers: [VirtualPrinter] = []
    /// Table code modèle → nom affichable, pour les sélecteurs.
    private(set) var models: [String: String] = [:]
    private(set) var hasLoaded = false
    var loadError: String?
    var actionMessage: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    /// Modèles triés par nom affichable, pour les pickers.
    var sortedModels: [(code: String, name: String)] {
        models
            .map { (code: $0.key, name: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let list = try await client.virtualPrinters()
            printers = list.printers
            models = list.models
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Crée une imprimante virtuelle puis recharge. Renvoie `true` au succès.
    func create(_ create: VirtualPrinterCreate) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.createVirtualPrinter(create)
            await load()
            actionMessage = nil
            return true
        } catch {
            actionMessage = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Met à jour une imprimante virtuelle puis recharge. Renvoie `true` au succès.
    func update(id: Int, _ update: VirtualPrinterUpdate) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.updateVirtualPrinter(id: id, update)
            await load()
            actionMessage = nil
            return true
        } catch {
            actionMessage = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Supprime une imprimante virtuelle puis recharge.
    func delete(_ printer: VirtualPrinter) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteVirtualPrinter(id: printer.id)
            await load()
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }
}
