// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de la bibliothèque de modèles d'un serveur (lecture, REST).
@MainActor
@Observable
final class LibraryListModel {
    private(set) var files: [LibraryFile] = []
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
            files = try await client.libraryFiles()
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Ajoute un fichier à la file d'attente d'impression. Renvoie `true` au succès.
    func enqueue(_ file: LibraryFile) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.addToQueue(QueueItemCreate(libraryFileId: file.id))
            loadError = nil
            return true
        } catch {
            loadError = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Applique une édition (nom, notes) et met à jour l'élément en place.
    func update(_ file: LibraryFile, with edit: LibraryFileUpdate) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let updated = try await client.updateLibraryFile(id: file.id, edit)
            if let index = files.firstIndex(where: { $0.id == updated.id }) {
                files[index] = updated
            }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Supprime un fichier (corbeille serveur) puis le retire de la liste.
    func delete(_ file: LibraryFile) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteLibraryFile(id: file.id)
            files.removeAll { $0.id == file.id }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }
}
