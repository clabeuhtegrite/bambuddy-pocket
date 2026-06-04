// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de l'archive d'impressions d'un serveur (lecture seule, REST).
@MainActor
@Observable
final class ArchiveListModel {
    private(set) var archives: [Archive] = []
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
            archives = try await client.archives()
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Récupère les statistiques globales d'impression (`nil` en cas d'échec).
    func fetchStats() async -> ArchiveStats? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.archiveStats()
        } catch {
            return nil
        }
    }

    /// Ajoute une archive à la file d'attente d'impression. Renvoie `true` au succès.
    func enqueue(_ archive: Archive) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.addToQueue(QueueItemCreate(archiveId: archive.id))
            return true
        } catch {
            loadError = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Recherche plein-texte côté serveur ; replie sur la dernière liste chargée si la requête
    /// est trop courte. Met à jour `archives` avec les résultats.
    func search(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            await load()
            return
        }
        do {
            let client = try connectionFactory.makeClient(for: server)
            archives = try await client.searchArchives(trimmed)
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Bascule le favori d'une archive et met à jour l'élément en place.
    func toggleFavorite(_ archive: Archive) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let updated = try await client.toggleArchiveFavorite(id: archive.id)
            replace(updated)
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Applique une édition de métadonnées (tags, notes, nom, lien) et met à jour en place.
    func update(_ archive: Archive, with edit: ArchiveUpdate) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let updated = try await client.updateArchive(id: archive.id, edit)
            replace(updated)
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Supprime une archive du serveur puis la retire de la liste.
    func delete(_ archive: Archive) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteArchive(id: archive.id)
            archives.removeAll { $0.id == archive.id }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    private func replace(_ archive: Archive) {
        if let index = archives.firstIndex(where: { $0.id == archive.id }) {
            archives[index] = archive
        }
    }

    /// Télécharge le fichier d'une archive et déduit son format (extension) pour le viewer 3D.
    func downloadModel(_ archive: Archive) async -> ModelPayload? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let data = try await client.downloadArchive(id: archive.id)
            let ext = archive.filename
                .map { ($0 as NSString).pathExtension.lowercased() }
                .flatMap { $0.isEmpty ? nil : $0 } ?? "3mf"
            return ModelPayload(data: data, ext: ext)
        } catch {
            return nil
        }
    }

    /// Récupère les octets de la vignette d'une archive ; `nil` si absente ou en cas d'échec.
    /// La vignette exige un **jeton de flux** (`?token=`) quand l'auth est activée (chargée sans
    /// en-tête d'autorisation côté serveur) ; le jeton est inoffensif si l'auth est désactivée.
    func thumbnail(_ archive: Archive) async -> Data? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let token = try? await client.cameraStreamToken().token
            return try await client.archiveThumbnail(id: archive.id, token: token)
        } catch {
            return nil
        }
    }

    /// Métadonnées du timelapse d'une archive ; `nil` si absent ou en cas d'échec.
    func timelapseInfo(_ archive: Archive) async -> TimelapseInfo? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.timelapseInfo(archiveID: archive.id)
        } catch {
            return nil
        }
    }
}
