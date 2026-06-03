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
}
