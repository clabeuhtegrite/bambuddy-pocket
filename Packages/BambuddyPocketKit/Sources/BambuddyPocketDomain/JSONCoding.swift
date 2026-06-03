// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public extension JSONDecoder {
    /// Décodeur configuré pour les DTO de l'API Bambuddy (clés `snake_case`, dates ISO-8601).
    /// À n'utiliser que pour les modèles **réseau**, pas pour la persistance interne de l'app.
    static func bambuddy() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

public extension JSONEncoder {
    /// Encodeur symétrique de `JSONDecoder.bambuddy()` (pour les corps de requête API).
    static func bambuddy() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
