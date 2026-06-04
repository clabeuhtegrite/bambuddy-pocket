// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de la découverte réseau d'imprimantes : état, sous-réseaux, lancement/arrêt, liste.
@MainActor
@Observable
final class DiscoveryModel {
    private(set) var info: DiscoveryInfo?
    private(set) var printers: [DiscoveredPrinter] = []
    private(set) var isRunning = false
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
            async let loadedInfo = client.discoveryInfo()
            async let status = client.discoveryStatus()
            async let loadedPrinters = client.discoveredPrinters()
            info = try? await loadedInfo
            isRunning = await (try? status)?.isRunning ?? false
            printers = await (try? loadedPrinters) ?? []
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Démarre ou arrête la découverte puis recharge l'état et la liste.
    func toggle() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let status = isRunning ? try await client.stopDiscovery() : try await client.startDiscovery()
            isRunning = status.isRunning
            loadError = nil
            await refreshPrinters()
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Recharge la liste des imprimantes découvertes (sans toucher à l'état).
    func refreshPrinters() async {
        guard let client = try? connectionFactory.makeClient(for: server) else {
            return
        }
        printers = await (try? client.discoveredPrinters()) ?? printers
    }
}
