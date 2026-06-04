// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model des réglages serveur (langue, devise, imprimante par défaut, coûts).
/// Charge `GET /settings/` + la liste des imprimantes (pour le sélecteur d'imprimante par défaut)
/// et applique les modifications via `PATCH /settings/`.
@MainActor
@Observable
final class SettingsModel {
    private(set) var settings: AppSettings?
    private(set) var printers: [Printer] = []
    private(set) var hasLoaded = false
    private(set) var isSaving = false
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
            async let loaded = client.settings()
            async let printerList = client.printers()
            settings = try await loaded
            printers = await (try? printerList) ?? []
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Applique une mise à jour partielle et reflète l'état renvoyé par le serveur.
    func apply(_ update: AppSettingsUpdate) async {
        isSaving = true
        defer { isSaving = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            settings = try await client.updateSettings(update)
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }
}
