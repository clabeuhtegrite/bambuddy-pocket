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
}
