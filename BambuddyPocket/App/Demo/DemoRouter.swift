// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Achemine un chemin REST (`/api/v1/...`) vers la fixture JSON correspondante pour le mode démo.
/// Tout chemin non couvert renvoie `200 []` (liste vide) ou `200 {}` afin que les écrans dégradent
/// proprement (états vides) au lieu de planter. Aucune écriture, aucun effet de bord.
enum DemoRouter {
    /// Préfixe REST commun (`/api/v1`).
    private static let prefix = "/api/v1"

    /// Type de contenu d'une réponse (JSON par défaut, ou binaire pour les téléchargements).
    static func contentType(forPath rawPath: String) -> String {
        let path = normalized(rawPath)
        if path.hasPrefix("/archives/"), path.hasSuffix("/download") {
            return "text/plain; charset=utf-8"
        }
        return "application/json; charset=utf-8"
    }

    /// Retourne `(statusCode, corps)` pour un chemin donné.
    static func response(forPath rawPath: String, query: String?) -> (Int, Data) {
        let path = normalized(rawPath)

        // Téléchargement d'archive → G-code de démo (tracé d'outil pour le viewer 3D).
        if path.hasPrefix("/archives/"), path.hasSuffix("/download") {
            return (200, Data(DemoToolpath.gcode.utf8))
        }

        switch path {
        case "/printers/", "/printers":
            return ok(DemoFixtures.printers)
        case "/queue/", "/queue":
            return ok(DemoFixtures.queue)
        case "/notifications/logs":
            return ok(DemoFixtures.activityLog)
        case "/library/files/", "/library/files":
            // La racine ne renvoie que les fichiers sans dossier ; les requêtes filtrées par
            // `folder_id` renvoient une liste vide (pas de sous-dossier en démo).
            return (query?.contains("folder_id") ?? false) ? ok("[]") : ok(DemoFixtures.libraryFiles)
        case "/library/folders/", "/library/folders":
            return ok("[]")
        case "/settings/", "/settings":
            return ok(DemoFixtures.settings)
        case "/system/info":
            return ok(DemoFixtures.systemInfo)
        case "/archives/", "/archives":
            return ok(DemoFixtures.archives)
        case "/archives/search":
            return ok(DemoFixtures.archives)
        default:
            return fallback(forPath: path)
        }
    }

    /// Replis paramétrés (chemins avec identifiants).
    private static func fallback(forPath path: String) -> (Int, Data) {
        // GET /printers/{id}/status → imprimante 1 en cours (statut riche), les autres au repos
        // (variété visuelle : une presse imprime, une autre est prête).
        if path.hasPrefix("/printers/"), path.hasSuffix("/status") {
            return ok(path.hasPrefix("/printers/1/") ? DemoFixtures.printerStatus : DemoFixtures.printerStatusIdle)
        }
        // GET /archives/{id} → premier élément détaillé.
        if path.hasPrefix("/archives/"), path.split(separator: "/").count == 2 {
            return ok(DemoFixtures.archiveDetail)
        }
        // Listes inconnues → vide ; objets inconnus → objet vide. On répond toujours 200 pour
        // éviter des bannières d'erreur sur les captures.
        return ok("[]")
    }

    /// Normalise le chemin en retirant le préfixe `/api/v1`.
    private static func normalized(_ rawPath: String) -> String {
        guard rawPath.hasPrefix(prefix) else { return rawPath }
        let trimmed = String(rawPath.dropFirst(prefix.count))
        return trimmed.isEmpty ? "/" : trimmed
    }

    private static func ok(_ json: String) -> (Int, Data) {
        (200, Data(json.utf8))
    }
}
