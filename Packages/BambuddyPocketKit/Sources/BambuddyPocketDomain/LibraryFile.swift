// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Un fichier de la bibliothèque de modèles (`GET /library/files/`, `FileListResponse`).
public struct LibraryFile: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var filename: String
    public var fileType: String?
    public var fileSize: Int?
    public var printName: String?
    public var printCount: Int?
    public var printTimeSeconds: Int?
    public var filamentUsedGrams: Double?
    public var createdAt: String?

    public init(id: Int, filename: String) {
        self.id = id
        self.filename = filename
    }

    /// Nom à afficher : nom d'impression si présent, sinon nom de fichier.
    public var displayName: String {
        if let printName, !printName.isEmpty {
            return printName
        }
        return filename
    }
}
