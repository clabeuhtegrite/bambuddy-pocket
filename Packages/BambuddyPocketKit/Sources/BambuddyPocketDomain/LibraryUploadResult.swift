// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Résultat d'un téléversement de fichier dans la bibliothèque (`POST /library/files/`,
/// `FileUploadResponse`). `duplicateOf` est renseigné quand un fichier au même hachage existe déjà.
public struct LibraryUploadResult: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var filename: String
    public var fileType: String?
    public var fileSize: Int?
    public var thumbnailPath: String?
    /// Identifiant d'un fichier existant au contenu identique (doublon), le cas échéant.
    public var duplicateOf: Int?

    public init(
        id: Int,
        filename: String,
        fileType: String? = nil,
        fileSize: Int? = nil,
        thumbnailPath: String? = nil,
        duplicateOf: Int? = nil
    ) {
        self.id = id
        self.filename = filename
        self.fileType = fileType
        self.fileSize = fileSize
        self.thumbnailPath = thumbnailPath
        self.duplicateOf = duplicateOf
    }

    /// Le fichier téléversé est-il un doublon d'un fichier déjà présent ?
    public var isDuplicate: Bool {
        duplicateOf != nil
    }
}
