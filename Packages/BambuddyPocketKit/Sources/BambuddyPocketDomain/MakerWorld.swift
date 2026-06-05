// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État de l'intégration MakerWorld (`GET /makerworld/status`). L'import nécessite un jeton
/// Bambu Cloud côté serveur (`hasCloudToken`) ; `canDownload` confirme la capacité de
/// téléchargement.
public struct MakerWorldStatus: Codable, Sendable, Hashable {
    public var hasCloudToken: Bool
    public var canDownload: Bool

    public init(hasCloudToken: Bool = false, canDownload: Bool = false) {
        self.hasCloudToken = hasCloudToken
        self.canDownload = canDownload
    }
}

/// Import récent depuis MakerWorld (`GET /makerworld/recent-imports`).
public struct MakerWorldRecentImport: Codable, Sendable, Hashable, Identifiable {
    public var libraryFileId: Int
    public var filename: String
    public var folderId: Int?
    public var thumbnailPath: String?
    public var sourceUrl: String?
    public var createdAt: String

    public var id: Int {
        libraryFileId
    }

    public init(
        libraryFileId: Int,
        filename: String,
        folderId: Int? = nil,
        thumbnailPath: String? = nil,
        sourceUrl: String? = nil,
        createdAt: String
    ) {
        self.libraryFileId = libraryFileId
        self.filename = filename
        self.folderId = folderId
        self.thumbnailPath = thumbnailPath
        self.sourceUrl = sourceUrl
        self.createdAt = createdAt
    }
}

/// Corps de résolution d'une URL publique MakerWorld (`POST /makerworld/resolve`).
public struct MakerWorldResolveRequest: Codable, Sendable, Hashable {
    public var url: String

    public init(url: String) {
        self.url = url
    }
}

/// Modèle résolu depuis une URL publique MakerWorld (`POST /makerworld/resolve`).
/// `design` et `instances` sont des objets souples côté serveur : on décode défensivement les
/// champs utiles à l'affichage et au choix d'une plate à importer.
public struct MakerWorldResolvedModel: Codable, Sendable, Hashable {
    public var modelId: Int
    public var profileId: Int?
    public var design: MakerWorldDesign
    public var instances: [MakerWorldInstance]
    public var alreadyImportedLibraryIds: [Int]

    public init(
        modelId: Int,
        profileId: Int? = nil,
        design: MakerWorldDesign,
        instances: [MakerWorldInstance] = [],
        alreadyImportedLibraryIds: [Int] = []
    ) {
        self.modelId = modelId
        self.profileId = profileId
        self.design = design
        self.instances = instances
        self.alreadyImportedLibraryIds = alreadyImportedLibraryIds
    }
}

/// Métadonnées d'un design MakerWorld (sous-objet souple : champs décodés défensivement).
public struct MakerWorldDesign: Codable, Sendable, Hashable {
    public var title: String?
    public var designer: String?
    public var coverUrl: String?

    public init(title: String? = nil, designer: String? = nil, coverUrl: String? = nil) {
        self.title = title
        self.designer = designer
        self.coverUrl = coverUrl
    }

    private enum CodingKeys: String, CodingKey {
        case title, name
        case designer, designerName
        case coverUrl, cover, coverImage
    }

    public init(from decoder: any Decoder) throws {
        // Le décodeur applique `.convertFromSnakeCase` : les clés JSON arrivent déjà en camelCase,
        // donc les valeurs brutes des `CodingKeys` sont en camelCase (pas en snake_case).
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
            ?? container.decodeIfPresent(String.self, forKey: .name)
        designer = try container.decodeIfPresent(String.self, forKey: .designer)
            ?? container.decodeIfPresent(String.self, forKey: .designerName)
        coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
            ?? container.decodeIfPresent(String.self, forKey: .cover)
            ?? container.decodeIfPresent(String.self, forKey: .coverImage)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(designer, forKey: .designer)
        try container.encodeIfPresent(coverUrl, forKey: .coverUrl)
    }
}

/// Une plate/instance importable d'un modèle MakerWorld (sous-objet souple).
public struct MakerWorldInstance: Codable, Sendable, Hashable, Identifiable {
    public var instanceId: Int
    public var name: String?
    public var thumbnailUrl: String?

    public var id: Int {
        instanceId
    }

    public init(instanceId: Int, name: String? = nil, thumbnailUrl: String? = nil) {
        self.instanceId = instanceId
        self.name = name
        self.thumbnailUrl = thumbnailUrl
    }

    private enum CodingKeys: String, CodingKey {
        case instanceId, id
        case name, title
        case thumbnailUrl, thumbnail
    }

    public init(from decoder: any Decoder) throws {
        // `.convertFromSnakeCase` actif : les clés arrivent en camelCase.
        let container = try decoder.container(keyedBy: CodingKeys.self)
        instanceId = try container.decodeIfPresent(Int.self, forKey: .instanceId)
            ?? container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name)
            ?? container.decodeIfPresent(String.self, forKey: .title)
        thumbnailUrl = try container.decodeIfPresent(String.self, forKey: .thumbnailUrl)
            ?? container.decodeIfPresent(String.self, forKey: .thumbnail)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(instanceId, forKey: .instanceId)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(thumbnailUrl, forKey: .thumbnailUrl)
    }
}

/// Corps d'import d'un modèle MakerWorld dans la bibliothèque serveur (`POST /makerworld/import`).
public struct MakerWorldImportRequest: Codable, Sendable, Hashable {
    public var modelId: Int
    public var profileId: Int?
    public var instanceId: Int?
    public var folderId: Int?

    public init(modelId: Int, profileId: Int? = nil, instanceId: Int? = nil, folderId: Int? = nil) {
        self.modelId = modelId
        self.profileId = profileId
        self.instanceId = instanceId
        self.folderId = folderId
    }
}

/// Réponse d'import MakerWorld (`POST /makerworld/import`).
public struct MakerWorldImportResponse: Codable, Sendable, Hashable {
    public var libraryFileId: Int
    public var filename: String
    public var folderId: Int?
    public var profileId: Int?
    public var wasExisting: Bool

    public init(
        libraryFileId: Int,
        filename: String,
        folderId: Int? = nil,
        profileId: Int? = nil,
        wasExisting: Bool = false
    ) {
        self.libraryFileId = libraryFileId
        self.filename = filename
        self.folderId = folderId
        self.profileId = profileId
        self.wasExisting = wasExisting
    }
}
