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
    /// Le serveur a refusé l'accès (HTTP 403) : fonction d'administration réservée à une connexion
    /// par identifiants. Avec une clé d'API, c'est le comportement **attendu** côté Bambuddy. L'UI
    /// affiche un message d'orientation et masque les actions (« Sauvegarder maintenant »).
    private(set) var isForbidden = false
    /// La fonctionnalité de sauvegardes locales n'est pas disponible sur ce serveur (HTTP 404) :
    /// l'UI affiche un état « non disponible » et masque les actions.
    private(set) var isUnavailable = false
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
            isForbidden = false
            isUnavailable = false
        } catch let apiError as APIError where apiError.isForbidden {
            isForbidden = true
            isUnavailable = false
            loadError = ErrorMessage.text(for: apiError)
        } catch let apiError as APIError where apiError.isNotFound {
            isUnavailable = true
            isForbidden = false
            loadError = nil
        } catch {
            isForbidden = false
            isUnavailable = false
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
