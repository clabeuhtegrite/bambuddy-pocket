// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model des mises à jour firmware d'un serveur (lecture seule).
@MainActor
@Observable
final class FirmwareModel {
    private(set) var updates: [FirmwareUpdate] = []
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
            updates = try await client.firmwareUpdates().updates ?? []
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }
}
