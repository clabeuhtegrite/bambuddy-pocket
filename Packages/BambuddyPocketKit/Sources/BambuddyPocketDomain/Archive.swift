// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Une archive d'impression (`GET /archives/` et `/archives/{id}`).
///
/// Sous-ensemble robuste de `ArchiveResponse` (55 champs) limité à ce que l'app affiche. Les
/// dates sont conservées en `String` (ISO brut) pour ne dépendre d'aucune stratégie de décodage.
/// Les champs non modélisés du serveur sont ignorés au décodage.
public struct Archive: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var printerId: Int?
    public var printName: String?
    public var filename: String?
    public var status: String
    public var startedAt: String?
    public var completedAt: String?
    public var createdAt: String?
    public var printTimeSeconds: Int?
    public var actualTimeSeconds: Int?
    public var totalLayers: Int?
    public var filamentUsedGrams: Double?
    public var filamentType: String?
    public var filamentColor: String?
    public var cost: Double?
    public var energyKwh: Double?
    public var isFavorite: Bool?
    public var designer: String?
    public var runCount: Int?

    public init(id: Int, status: String) {
        self.id = id
        self.status = status
    }

    /// Nom à afficher : nom d'impression si présent, sinon nom de fichier, sinon « #id ».
    public var displayName: String {
        if let printName, !printName.isEmpty {
            return printName
        }
        if let filename, !filename.isEmpty {
            return filename
        }
        return "#\(id)"
    }
}
