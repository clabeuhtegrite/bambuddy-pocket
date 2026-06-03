// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Un élément de la file d'attente d'impression (`GET /queue/`).
///
/// Sous-ensemble robuste de `PrintQueueItemResponse` (47 champs) limité à l'affichage. Les
/// champs non modélisés sont ignorés au décodage ; les dates restent en `String` (ISO brut).
public struct QueueItem: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var position: Int
    public var status: String
    public var printerName: String?
    public var archiveName: String?
    public var libraryFileName: String?
    public var printTimeSeconds: Int?
    public var filamentUsedGrams: Double?
    public var waitingReason: String?
    public var errorMessage: String?
    public var scheduledTime: String?
    public var beenJumped: Bool?

    public init(id: Int, position: Int, status: String) {
        self.id = id
        self.position = position
        self.status = status
    }

    /// Nom à afficher : archive, sinon fichier de bibliothèque, sinon « #id ».
    public var displayName: String {
        if let archiveName, !archiveName.isEmpty {
            return archiveName
        }
        if let libraryFileName, !libraryFileName.isEmpty {
            return libraryFileName
        }
        return "#\(id)"
    }
}

/// Une paire (id, position) pour le réordonnancement de la file.
public struct QueueReorderItem: Codable, Sendable, Hashable {
    public var id: Int
    public var position: Int

    public init(id: Int, position: Int) {
        self.id = id
        self.position = position
    }
}

/// Corps de `POST /queue/reorder` (`PrintQueueReorder`).
public struct QueueReorder: Codable, Sendable, Hashable {
    public var items: [QueueReorderItem]

    public init(items: [QueueReorderItem]) {
        self.items = items
    }
}

/// Corps minimal d'ajout à la file (`POST /queue/`, `PrintQueueItemCreate`) : depuis une archive
/// ou un fichier de bibliothèque. Les nombreux autres champs gardent leurs valeurs serveur.
public struct QueueItemCreate: Codable, Sendable, Hashable {
    public var archiveId: Int?
    public var libraryFileId: Int?
    public var printerId: Int?
    public var quantity: Int

    public init(archiveId: Int? = nil, libraryFileId: Int? = nil, printerId: Int? = nil, quantity: Int = 1) {
        self.archiveId = archiveId
        self.libraryFileId = libraryFileId
        self.printerId = printerId
        self.quantity = quantity
    }
}
