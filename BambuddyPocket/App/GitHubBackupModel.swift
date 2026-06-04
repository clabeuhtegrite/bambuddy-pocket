// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de la sauvegarde distante Git d'un serveur (`/github-backup/`) : état, configuration
/// (lecture seule + édition), journal et déclenchement manuel.
///
/// Sécurité : le **jeton d'accès** n'est jamais renvoyé par le serveur (`has_token` seulement) ni
/// stocké sur l'appareil. Il est saisi dans le formulaire et transmis **en écriture seule** au
/// serveur lors de l'enregistrement — l'app n'en garde aucune trace.
@MainActor
@Observable
final class GitHubBackupModel {
    private(set) var status: GitHubBackupStatus?
    private(set) var config: GitHubBackupConfig?
    private(set) var logs: [GitHubBackupLog] = []
    private(set) var hasLoaded = false
    private(set) var isRunning = false
    var loadError: String?
    var actionMessage: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    /// La sauvegarde distante est-elle configurée sur ce serveur ?
    var isConfigured: Bool {
        status?.configured ?? (config != nil)
    }

    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            status = try await client.gitHubBackupStatus()
            config = try await client.gitHubBackupConfig()
            logs = await (try? client.gitHubBackupLogs()) ?? []
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Crée la configuration (jeton requis). À utiliser quand aucune config n'existe.
    func create(_ create: GitHubBackupConfigCreate) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            config = try await client.saveGitHubBackupConfig(create)
            await load()
            actionMessage = nil
            return true
        } catch {
            actionMessage = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Met à jour partiellement la configuration existante (jeton préservé si non fourni).
    func update(_ update: GitHubBackupConfigUpdate) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            config = try await client.updateGitHubBackupConfig(update)
            await load()
            actionMessage = nil
            return true
        } catch {
            actionMessage = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Supprime la configuration puis recharge.
    func deleteConfig() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteGitHubBackupConfig()
            await load()
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }

    /// Déclenche une sauvegarde manuelle puis recharge l'état et le journal.
    func runNow() async {
        isRunning = true
        defer { isRunning = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            let result = try await client.runGitHubBackup()
            actionMessage = result.message
            await load()
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }
}
