// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model du support / diagnostic d'un serveur (`/support/`) : journal de débogage et
/// consultation/filtrage/effacement du journal applicatif.
@MainActor
@Observable
final class SupportModel {
    private(set) var debugState: DebugLoggingState?
    private(set) var entries: [LogEntry] = []
    private(set) var totalInFile = 0
    private(set) var hasLoaded = false
    private(set) var isBusy = false
    var loadError: String?
    var actionMessage: String?

    /// Filtre de niveau courant (`nil` = tous).
    var levelFilter: String?
    /// Recherche plein-texte courante.
    private var query = ""

    private let limit = 200
    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            debugState = try await client.debugLoggingState()
            let logs = try await client.serverLogs(limit: limit, level: levelFilter, search: query)
            entries = logs.entries
            totalInFile = logs.totalInFile
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Recharge uniquement les entrées de journal avec les filtres courants.
    func reloadLogs() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let logs = try await client.serverLogs(limit: limit, level: levelFilter, search: query)
            entries = logs.entries
            totalInFile = logs.totalInFile
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Met à jour le filtre de recherche puis recharge les entrées.
    func search(_ text: String) async {
        query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        await reloadLogs()
    }

    /// Applique un filtre de niveau puis recharge les entrées.
    func applyLevel(_ level: String?) async {
        levelFilter = level
        await reloadLogs()
    }

    /// Active ou désactive le journal de débogage puis met à jour l'état.
    func setDebugLogging(_ enabled: Bool) async {
        isBusy = true
        defer { isBusy = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            debugState = try await client.setDebugLogging(enabled: enabled)
            actionMessage = nil
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }

    /// Vide le journal applicatif côté serveur puis recharge.
    func clearLogs() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.clearServerLogs()
            await reloadLogs()
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }
}
