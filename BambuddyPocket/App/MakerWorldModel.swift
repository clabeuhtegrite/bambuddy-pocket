// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model de l'intégration **MakerWorld** d'un serveur (`/makerworld/`) : état (capacité
/// d'import), imports récents, **résolution** d'une URL publique (lecture) et **import** (qui
/// télécharge un 3MF côté serveur — réservé aux serveurs de développement).
@MainActor
@Observable
final class MakerWorldModel {
    private(set) var status: MakerWorldStatus?
    private(set) var recentImports: [MakerWorldRecentImport] = []
    private(set) var hasLoaded = false
    /// Fonction admin réservée à une connexion par identifiants (HTTP 403) → « connexion admin
    /// requise » (cf. #70).
    private(set) var isForbidden = false
    /// Intégration MakerWorld absente sur ce serveur (HTTP 404).
    private(set) var isUnavailable = false
    var loadError: String?

    /// Résultat de la dernière résolution d'URL (liste de plates importables).
    private(set) var resolved: MakerWorldResolvedModel?
    private(set) var isResolving = false
    private(set) var isImporting = false
    var actionMessage: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    /// Le serveur peut-il télécharger depuis MakerWorld (jeton cloud présent) ?
    var canImport: Bool {
        status?.canDownload ?? false
    }

    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            status = try await client.makerWorldStatus()
            recentImports = await (try? client.makerWorldRecentImports()) ?? []
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

    /// Résout une URL publique MakerWorld (lecture : aucun téléchargement).
    func resolve(url: String) async {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isResolving = true
        defer { isResolving = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            resolved = try await client.resolveMakerWorld(url: trimmed)
            actionMessage = nil
        } catch {
            resolved = nil
            actionMessage = ErrorMessage.text(for: error)
        }
    }

    /// Importe une plate résolue dans la bibliothèque serveur. ⚠️ Télécharge un 3MF côté serveur.
    func importPlate(instanceId: Int?, folderId: Int? = nil) async {
        guard let resolved else { return }
        isImporting = true
        defer { isImporting = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            let response = try await client.importMakerWorld(
                MakerWorldImportRequest(
                    modelId: resolved.modelId,
                    profileId: resolved.profileId,
                    instanceId: instanceId,
                    folderId: folderId
                )
            )
            actionMessage = response.wasExisting
                ? String(localized: "Already in your library: \(response.filename)")
                : String(localized: "Imported \(response.filename)")
            await load()
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }

    /// Efface le résultat de résolution courant.
    func clearResolved() {
        resolved = nil
    }
}
