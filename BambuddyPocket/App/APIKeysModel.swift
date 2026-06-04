// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model des clés d'API d'un serveur : liste, création, révocation, suppression.
@MainActor
@Observable
final class APIKeysModel {
    private(set) var keys: [APIKey] = []
    private(set) var hasLoaded = false
    var loadError: String?
    /// Secret complet de la clé qui vient d'être créée (à n'afficher qu'une fois).
    var createdSecret: APIKey?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            keys = try await client.apiKeys()
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Crée une clé et conserve le secret renvoyé (affiché une seule fois), puis recharge la liste.
    func create(_ create: APIKeyCreate) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let created = try await client.createAPIKey(create)
            createdSecret = created
            loadError = nil
            await load()
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Active ou révoque une clé (`enabled`) et met à jour l'élément en place.
    func setEnabled(_ key: APIKey, enabled: Bool) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let updated = try await client.updateAPIKey(id: key.id, APIKeyUpdate(enabled: enabled))
            if let index = keys.firstIndex(where: { $0.id == updated.id }) {
                keys[index] = updated
            }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Supprime une clé puis la retire de la liste.
    func delete(_ key: APIKey) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteAPIKey(id: key.id)
            keys.removeAll { $0.id == key.id }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }
}
