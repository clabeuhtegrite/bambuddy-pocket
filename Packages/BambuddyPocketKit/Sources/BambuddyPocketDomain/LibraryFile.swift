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
    public var folderId: Int?
    public var notes: String?
    public var slicedForModel: String?

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

    /// `true` si le fichier est tranché (imprimable) — extension `.gcode` ou `.gcode.3mf`.
    public var isSliced: Bool {
        let lower = filename.lowercased()
        return lower.hasSuffix(".gcode") || lower.hasSuffix(".gcode.3mf")
    }

    /// `true` si le fichier peut être **tranché** (modèle source) : STL, STEP/STP, ou 3MF non encore
    /// tranché. Aligné sur le serveur (`POST /library/files/{id}/slice` : « Source file must be STL,
    /// 3MF, or STEP »).
    public var isSliceable: Bool {
        let lower = filename.lowercased()
        if lower.hasSuffix(".stl") || lower.hasSuffix(".step") || lower.hasSuffix(".stp") {
            return true
        }
        // Un 3MF déjà tranché (`.gcode.3mf`) n'est pas une source de découpe.
        return lower.hasSuffix(".3mf") && !isSliced
    }
}

/// Corps d'édition d'un fichier de bibliothèque (`PUT /library/files/{id}`, `FileUpdate`). Tous les
/// champs sont optionnels : seuls les champs non `nil` sont encodés.
public struct LibraryFileUpdate: Codable, Sendable, Hashable {
    public var filename: String?
    public var notes: String?
    public var folderId: Int?
    public var projectId: Int?

    public init(filename: String? = nil, notes: String? = nil, folderId: Int? = nil, projectId: Int? = nil) {
        self.filename = filename
        self.notes = notes
        self.folderId = folderId
        self.projectId = projectId
    }
}
