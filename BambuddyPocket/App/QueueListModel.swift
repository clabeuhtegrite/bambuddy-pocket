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
            items = try await client.queue().sorted { $0.position < $1.position }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Réordonne localement puis persiste le nouvel ordre sur le serveur.
    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        let reordered = items.enumerated().map { offset, item in
            QueueReorderItem(id: item.id, position: offset + 1)
        }
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

    func delete(_ item: QueueItem) async {
        await act { try await $0.deleteQueueItem(id: item.id) }
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
