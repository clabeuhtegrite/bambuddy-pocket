// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de la file d'attente d'impression d'un serveur (lecture, REST).
@MainActor
@Observable
final class QueueListModel {
    private(set) var items: [QueueItem] = []
    private(set) var batches: [PrintBatch] = []
    private(set) var printers: [Printer] = []
    private(set) var hasLoaded = false
    var loadError: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    /// Éléments **actifs** de la file (en attente / en cours) : seuls ceux-ci sont ordonnés et
    /// réordonnables. `GET /queue/` renvoie aussi les éléments terminaux (historique) mélangés ;
    /// on les sépare ici comme le fait le tableau de bord web (sections « File » / « Historique »).
    var activeItems: [QueueItem] {
        items.filter { !$0.isTerminal }
    }

    /// Éléments **terminaux** (terminés / échoués / annulés / ignorés) — l'« Historique » de la file.
    /// Triés du plus récent au plus ancien (id décroissant : un id plus élevé a été créé plus tard),
    /// faute d'horodatage de fin fiable dans le sous-ensemble modélisé.
    var historyItems: [QueueItem] {
        items.filter(\.isTerminal).sorted { $0.id > $1.id }
    }

    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            async let items = client.queue()
            async let batches = client.queueBatches()
            async let printers = client.printers()
            self.items = try await items.sorted { $0.position < $1.position }
            self.batches = try await batches
            self.printers = try await printers
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Réordonne localement puis persiste le nouvel ordre sur le serveur. Les indices reçus portent
    /// sur les **éléments actifs** affichés (`activeItems`) — les seuls réordonnables ; on recompose
    /// ensuite `items` en conservant l'historique (éléments terminaux) inchangé.
    func move(from source: IndexSet, to destination: Int) {
        var active = activeItems
        active.move(fromOffsets: source, toOffset: destination)
        let reordered = active.enumerated().map { offset, item in
            QueueReorderItem(id: item.id, position: offset + 1)
        }
        // Reflète immédiatement le nouvel ordre actif dans `items` (historique préservé).
        items = active + items.filter(\.isTerminal)
        Task { await persist(reordered) }
    }

    private func persist(_ reordered: [QueueReorderItem]) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.reorderQueue(reordered)
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    func start(_ item: QueueItem) async {
        await act { try await $0.startQueueItem(id: item.id) }
    }

    func cancel(_ item: QueueItem) async {
        await act { try await $0.cancelQueueItem(id: item.id) }
    }

    func stop(_ item: QueueItem) async {
        await act { try await $0.stopQueueItem(id: item.id) }
    }

    func delete(_ item: QueueItem) async {
        await act { try await $0.deleteQueueItem(id: item.id) }
    }

    /// Applique une édition à un élément en attente puis recharge la file.
    func update(_ item: QueueItem, with edit: QueueItemUpdate) async {
        await act { _ = try await $0.updateQueueItem(id: item.id, edit) }
    }

    /// Annule un lot (tous ses éléments en attente) puis recharge.
    func cancelBatch(_ batch: PrintBatch) async {
        await act { try await $0.cancelQueueBatch(id: batch.id) }
    }

    private func act(_ action: (RESTClient) async throws -> Void) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await action(client)
            await load()
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }
}
