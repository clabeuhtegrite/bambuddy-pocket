// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de l'état serveur (`GET /system/info` + `GET /system/health`).
@MainActor
@Observable
final class SystemStatusModel {
    private(set) var info: SystemInfo?
    private(set) var health: SystemHealth?
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
            async let loadedInfo = client.systemInfo()
            async let loadedHealth = client.systemHealth()
            info = try await loadedInfo
            health = try? await loadedHealth
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }
}
