// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Endpoints REST de l’archive d’impressions (liste paginée, détail, stats, recherche,
/// édition, favori, suppression, timelapse). Extrait de `BambuddyEndpoints` (limite 500 l.).
public extension APIClient {
    /// Archive d'impressions (`GET /archives/`), la plus récente d'abord côté serveur.
    func archives() async throws -> [Archive] {
        try await get("/archives/")
    }

    /// Page de l'archive d'impressions (`GET /archives/?limit=&offset=`). Le serveur renvoie une
    /// simple liste (pas de total) : une page **pleine** signale qu'il reste potentiellement des
    /// éléments à charger. La plus récente d'abord.
    func archives(limit: Int, offset: Int) async throws -> [Archive] {
        try await get("/archives/?limit=\(limit)&offset=\(offset)")
    }

    /// Détail d'une archive (`GET /archives/{id}`).
    func archive(id: Int) async throws -> Archive {
        try await get("/archives/\(id)")
    }

    /// Statistiques globales d'impression (`GET /archives/stats`).
    func archiveStats() async throws -> ArchiveStats {
        try await get("/archives/stats")
    }

    /// Recherche plein-texte côté serveur (`GET /archives/search?q=…`). Le serveur exige au
    /// moins deux caractères ; renvoie une liste vide pour une requête plus courte.
    func searchArchives(_ query: String) async throws -> [Archive] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return try await get("/archives/search?q=\(encoded)")
    }

    /// Édite les métadonnées d'une archive (`PATCH /archives/{id}`) et renvoie l'archive à jour.
    func updateArchive(id: Int, _ update: ArchiveUpdate) async throws -> Archive {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/archives/\(id)", method: .patch, body: body)
    }

    /// Bascule le statut « favori » d'une archive (`POST /archives/{id}/favorite`).
    func toggleArchiveFavorite(id: Int) async throws -> Archive {
        try await send("/archives/\(id)/favorite", method: .post, body: nil)
    }

    /// Supprime une archive (`DELETE /archives/{id}`).
    func deleteArchive(id: Int) async throws {
        try await delete("/archives/\(id)")
    }

    /// Métadonnées de la vidéo timelapse d'une archive (`GET /archives/{id}/timelapse/info`).
    func timelapseInfo(archiveID: Int) async throws -> TimelapseInfo {
        try await get("/archives/\(archiveID)/timelapse/info")
    }
}
