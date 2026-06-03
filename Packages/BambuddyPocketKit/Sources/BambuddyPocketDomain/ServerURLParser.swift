// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Erreurs de normalisation d'une URL de serveur saisie par l'utilisateur.
public enum ServerURLError: Error, Sendable, Equatable {
    /// Saisie vide.
    case empty
    /// Saisie inexploitable (hôte manquant, caractères invalides…).
    case invalid
    /// Schéma non supporté (seuls `http` et `https` le sont).
    case unsupportedScheme(String)
}

/// Normalise une saisie utilisateur (« 192.168.1.50:8000 », « https://serveur.exemple »…) en
/// URL racine canonique : `schéma://hôte[:port]`, sans chemin, requête, fragment ni identifiants.
///
/// - Si aucun schéma n'est fourni, `http` est supposé (cas LAN courant).
/// - Seuls `http` et `https` sont acceptés.
public enum ServerURLParser {
    public static func normalize(_ raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServerURLError.empty }

        // Sans schéma explicite, on suppose http (les instances LAN sont souvent en clair).
        let withScheme = trimmed.contains("://") ? trimmed : "http://" + trimmed

        guard let comps = URLComponents(string: withScheme) else {
            throw ServerURLError.invalid
        }

        let scheme = (comps.scheme ?? "").lowercased()
        switch scheme {
        case "http", "https":
            break
        default:
            throw ServerURLError.unsupportedScheme(scheme)
        }

        guard let host = comps.host, !host.isEmpty else {
            throw ServerURLError.invalid
        }
        if let port = comps.port, port < 0 || port > 65535 {
            throw ServerURLError.invalid
        }

        // Ne conserver que schéma + hôte + port : on ignore chemin, requête, fragment, identifiants.
        var canonical = URLComponents()
        canonical.scheme = scheme
        canonical.host = host
        canonical.port = comps.port

        guard let url = canonical.url else { throw ServerURLError.invalid }
        return url
    }
}
