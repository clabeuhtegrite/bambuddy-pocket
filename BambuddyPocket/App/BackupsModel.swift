// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model des sauvegardes locales d'un serveur : état, liste des fichiers, déclenchement.
@MainActor
@Observable
final class BackupsModel {
    private(set) var status: BackupStatus?
    private(set) var backups: [BackupFile] = []
    private(set) var hasLoaded = false
    private(set) var isRunning = false
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
            async let loadedStatus = client.backupStatus()
            async let loadedBackups = client.backups()
            status = try await loadedStatus
            backups = await (try? loadedBackups) ?? []
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Déclenche une sauvegarde immédiate puis recharge l'état et la liste.
    func runBackup() async {
        isRunning = true
        defer { isRunning = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            _ = try await client.runBackup()
            loadError = nil
            await load()
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }
}
