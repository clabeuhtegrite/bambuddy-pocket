// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Un dossier de la bibliothèque, avec ses sous-dossiers (`GET /library/folders/`).
///
/// L'arbre est renvoyé sous forme récursive (`children`). Les dossiers peuvent être liés à un
/// projet ou une archive, ou être « externes » (montés depuis le système de fichiers du serveur).
public struct FolderTreeItem: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var parentID: Int?
    public var projectID: Int?
    public var archiveID: Int?
    public var projectName: String?
    public var archiveName: String?
    public var isExternal: Bool?
    public var externalPath: String?
    public var externalReadonly: Bool?
    public var fileCount: Int?
    public var children: [FolderTreeItem]?

    public init(id: Int, name: String, parentID: Int? = nil) {
        self.id = id
        self.name = name
        self.parentID = parentID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case parentID = "parentId"
        case projectID = "projectId"
        case archiveID = "archiveId"
        case projectName
        case archiveName
        case isExternal
        case externalPath
        case externalReadonly
        case fileCount
        case children
    }

    /// Sous-dossiers (jamais `nil` côté UI).
    public var subfolders: [FolderTreeItem] {
        children ?? []
    }
}

/// Corps de `POST /library/files/move` : déplace des fichiers vers un dossier (ou la racine si
/// `folderID` est `nil`).
public struct FileMoveRequest: Encodable, Sendable, Hashable {
    public var fileIDs: [Int]
    public var folderID: Int?

    public init(fileIDs: [Int], folderID: Int?) {
        self.fileIDs = fileIDs
        self.folderID = folderID
    }

    private enum CodingKeys: String, CodingKey {
        case fileIDs = "fileIds"
        case folderID = "folderId"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileIDs, forKey: .fileIDs)
        // `folder_id` est toujours encodé (y compris `null`) pour pouvoir replacer à la racine.
        try container.encode(folderID, forKey: .folderID)
    }
}

/// Réponse de `POST /library/files/move`.
public struct FileMoveResult: Codable, Sendable, Hashable {
    public var status: String?
    public var moved: Int?
    public var skipped: Int?

    public init(status: String? = nil, moved: Int? = nil, skipped: Int? = nil) {
        self.status = status
        self.moved = moved
        self.skipped = skipped
    }
}

/// Un fichier dans la corbeille (`GET /library/trash`).
public struct TrashFile: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var filename: String
    public var fileSize: Int?
    public var folderID: Int?
    public var folderName: String?
    public var deletedAt: String
    public var autoPurgeAt: String

    public init(id: Int, filename: String, deletedAt: String, autoPurgeAt: String) {
        self.id = id
        self.filename = filename
        self.deletedAt = deletedAt
        self.autoPurgeAt = autoPurgeAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case filename
        case fileSize
        case folderID = "folderId"
        case folderName
        case deletedAt
        case autoPurgeAt
    }
}

/// Réponse paginée de la corbeille (`GET /library/trash`).
public struct TrashListResponse: Codable, Sendable, Hashable {
    public var items: [TrashFile]
    public var total: Int
    public var retentionDays: Int

    public init(items: [TrashFile], total: Int, retentionDays: Int) {
        self.items = items
        self.total = total
        self.retentionDays = retentionDays
    }
}
