// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Tableau décodé de façon **tolérante** (« lossy ») : chaque élément est décodé indépendamment et
/// un élément malformé est **ignoré** au lieu de faire échouer tout le tableau (et, par ricochet,
/// tout le `PrinterStatus`). Indispensable pour les feeds hétérogènes (AMS, imports, logs) où une
/// seule entrée abîmée par le firmware/serveur ne doit pas effacer le reste.
public struct LossyArray<Element: Codable & Sendable>: Codable, Sendable {
    public let elements: [Element]

    public init(_ elements: [Element]) {
        self.elements = elements
    }

    public init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        if let count = container.count {
            result.reserveCapacity(count)
        }
        while !container.isAtEnd {
            // On consomme **toujours** un élément du conteneur (succès → on garde ; échec → on saute
            // via un décodage « poubelle » pour avancer le curseur sans casser l'itération).
            if let element = try? container.decode(Element.self) {
                result.append(element)
            } else {
                _ = try? container.decode(AnyDecodableSkip.self)
            }
        }
        elements = result
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        for element in elements {
            try container.encode(element)
        }
    }
}

/// Valeur jetable servant à **avancer** le curseur d'un conteneur non-clé quand l'élément courant
/// n'a pas pu être décodé dans le type attendu (sinon l'itération boucle indéfiniment).
private struct AnyDecodableSkip: Decodable {
    init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(), single.decodeNil() {
            return
        }
        // Tente de consommer l'élément quelle que soit sa forme (objet/tableau/scalaire).
        if var unkeyed = try? decoder.unkeyedContainer() {
            while !unkeyed.isAtEnd {
                _ = try? unkeyed.decode(AnyDecodableSkip.self)
            }
        } else if let keyed = try? decoder.container(keyedBy: AnyCodingKey.self) {
            for key in keyed.allKeys {
                _ = try? keyed.decode(AnyDecodableSkip.self, forKey: key)
            }
        }
    }

    private struct AnyCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            self.intValue = intValue
            stringValue = String(intValue)
        }
    }
}

/// Décodage **tolérant** d'un entier pouvant arriver en `Int`, `Double` (arrondi) ou `String`
/// numérique selon le firmware/serveur. Retourne `nil` si la clé est absente, `null`, ou non
/// convertible — jamais d'échec. Réplique l'esprit de `MakerWorldInstance.init(from:)`.
public enum TolerantInt {
    public static func decode<Key: CodingKey>(
        _ container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) -> Int? {
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return Int(value.rounded())
        }
        if let raw = try? container.decodeIfPresent(String.self, forKey: key) {
            return Int(raw) ?? Double(raw).map { Int($0.rounded()) }
        }
        return nil
    }
}
