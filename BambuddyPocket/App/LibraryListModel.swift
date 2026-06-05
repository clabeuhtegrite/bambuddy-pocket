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
    private(set) var folders: [FolderTreeItem] = []
    private(set) var hasLoaded = false
    var loadError: String?

    /// Fichiers chargés par dossier (`GET /library/files/?folder_id=…`). Le listing racine ne
    /// contient que les fichiers sans dossier ; le contenu d'un dossier doit être récupéré à part.
    private(set) var folderFiles: [Int: [LibraryFile]] = [:]
    /// Identifiants des dossiers dont le chargement est en cours (pour afficher un indicateur).
    private(set) var loadingFolders: Set<Int> = []

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
            // L'arbre des dossiers est secondaire : son échec ne doit pas masquer les fichiers.
            folders = await loadFolders(client)
            // Le contenu par dossier peut avoir changé (déplacement, téléversement, suppression) :
            // on invalide le cache pour qu'il soit re-récupéré à l'ouverture du dossier.
            folderFiles.removeAll()
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Charge l'arbre des dossiers sans propager l'erreur (liste vide en cas d'échec).
    private func loadFolders(_ client: RESTClient) async -> [FolderTreeItem] {
        do {
            return try await client.libraryFolders()
        } catch {
            return []
        }
    }

    /// Fichiers contenus dans un dossier (ou à la racine si `folderID` est `nil`).
    ///
    /// Pour la racine, on filtre la liste déjà chargée. Pour un dossier, on renvoie le contenu
    /// récupéré spécifiquement via `loadFolder(_:)` (le listing racine ne l'inclut pas).
    func files(inFolder folderID: Int?) -> [LibraryFile] {
        guard let folderID else {
            return files.filter { $0.folderId == nil }
        }
        return folderFiles[folderID] ?? []
    }

    /// Indique si le contenu d'un dossier a déjà été chargé (pour distinguer « vide » de « pas
    /// encore chargé »).
    func hasLoadedFolder(_ folderID: Int) -> Bool {
        folderFiles[folderID] != nil
    }

    /// Indique si le contenu d'un dossier est en cours de chargement.
    func isLoadingFolder(_ folderID: Int) -> Bool {
        loadingFolders.contains(folderID)
    }

    /// Charge (ou recharge) les fichiers d'un dossier via `GET /library/files/?folder_id=…`. En cas
    /// d'échec, l'erreur est exposée via `loadError` et le contenu reste celui déjà connu.
    func loadFolder(_ folderID: Int) async {
        loadingFolders.insert(folderID)
        defer { loadingFolders.remove(folderID) }
        do {
            let client = try connectionFactory.makeClient(for: server)
            folderFiles[folderID] = try await client.libraryFiles(inFolder: folderID)
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Déplace un fichier vers un dossier (ou la racine) puis recharge la liste.
    func move(_ file: LibraryFile, toFolder folderID: Int?) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.moveLibraryFiles(FileMoveRequest(fileIDs: [file.id], folderID: folderID))
            await load()
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Téléverse un fichier dans la bibliothèque (dans le dossier courant) puis recharge la liste.
    /// Renvoie le résultat (dont l'éventuel doublon) au succès, `nil` en cas d'échec.
    func upload(filename: String, data: Data, toFolder folderID: Int?) async -> LibraryUploadResult? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let result = try await client.uploadLibraryFile(filename: filename, data: data, folderID: folderID)
            await load()
            return result
        } catch {
            loadError = ErrorMessage.text(for: error)
            return nil
        }
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

    /// Applique une édition (nom, notes) et met à jour l'élément en place (racine **et** dossiers).
    func update(_ file: LibraryFile, with edit: LibraryFileUpdate) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let updated = try await client.updateLibraryFile(id: file.id, edit)
            if let index = files.firstIndex(where: { $0.id == updated.id }) {
                files[index] = updated
            }
            for (folderID, list) in folderFiles {
                if let index = list.firstIndex(where: { $0.id == updated.id }) {
                    folderFiles[folderID]?[index] = updated
                }
            }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Supprime un fichier (corbeille serveur) puis le retire de la liste (racine **et** dossiers).
    func delete(_ file: LibraryFile) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteLibraryFile(id: file.id)
            files.removeAll { $0.id == file.id }
            for folderID in folderFiles.keys {
                folderFiles[folderID]?.removeAll { $0.id == file.id }
            }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    // MARK: Corbeille

    private(set) var trash: TrashListResponse?
    private(set) var trashLoaded = false
    var trashError: String?

    /// Charge le contenu de la corbeille de la bibliothèque.
    func loadTrash() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            trash = try await client.libraryTrash()
            trashError = nil
        } catch {
            trashError = ErrorMessage.text(for: error)
        }
        trashLoaded = true
    }

    /// Restaure un fichier de la corbeille puis recharge la corbeille et la bibliothèque.
    func restore(_ item: TrashFile) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.restoreTrashedFile(id: item.id)
            await loadTrash()
            await load()
        } catch {
            trashError = ErrorMessage.text(for: error)
        }
    }

    /// Supprime définitivement un fichier de la corbeille puis recharge la corbeille.
    func purge(_ item: TrashFile) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteTrashedFile(id: item.id)
            await loadTrash()
        } catch {
            trashError = ErrorMessage.text(for: error)
        }
    }
}
