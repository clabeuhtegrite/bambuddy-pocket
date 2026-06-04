// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model des liens externes d'un serveur : liste, création, suppression.
@MainActor
@Observable
final class ExternalLinksModel {
    private(set) var links: [ExternalLink] = []
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
            links = try await client.externalLinks()
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Crée un lien puis recharge la liste.
    func create(name: String, url: String) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            _ = try await client.createExternalLink(ExternalLinkCreate(name: name, url: url))
            loadError = nil
            await load()
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Supprime un lien puis le retire de la liste.
    func delete(_ link: ExternalLink) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteExternalLink(id: link.id)
            links.removeAll { $0.id == link.id }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }
}
