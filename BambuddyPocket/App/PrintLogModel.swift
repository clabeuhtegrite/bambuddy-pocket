// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model du journal d'impression d'un serveur (`/print-log/`) : liste paginée, recherche
/// côté serveur et vidage. Lecture seule sauf le vidage destructif.
@MainActor
@Observable
final class PrintLogModel {
    private(set) var entries: [PrintLogEntry] = []
    private(set) var total = 0
    private(set) var hasLoaded = false
    private(set) var isLoadingMore = false
    var loadError: String?

    /// Recherche courante appliquée (pour la pagination cohérente).
    private var query = ""
    private let pageSize = 50
    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    /// Reste-t-il des entrées à charger au-delà de celles déjà affichées ?
    var canLoadMore: Bool {
        entries.count < total
    }

    func load() async {
        await reload(search: query)
    }

    /// Recherche côté serveur (filtre par nom de travail). Une chaîne vide recharge tout.
    func search(_ text: String) async {
        await reload(search: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func reload(search text: String) async {
        query = text
        do {
            let client = try connectionFactory.makeClient(for: server)
            let page = try await client.printLog(search: text, limit: pageSize, offset: 0)
            entries = page.items
            total = page.total
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Charge la page suivante et l'ajoute à la liste (dédoublonnée par identifiant).
    func loadMore() async {
        guard canLoadMore, !isLoadingMore else {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            let page = try await client.printLog(search: query, limit: pageSize, offset: entries.count)
            let known = Set(entries.map(\.id))
            entries.append(contentsOf: page.items.filter { !known.contains($0.id) })
            total = page.total
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Vide le journal côté serveur puis recharge (liste vide attendue).
    func clear() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.clearPrintLog()
            await reload(search: query)
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }
}
