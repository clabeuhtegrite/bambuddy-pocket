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
    public var printerId: Int?
    public var batchId: Int?
    public var batchName: String?
    public var manualStart: Bool?
    public var requirePreviousSuccess: Bool?
    public var autoOffAfter: Bool?
    public var bedLevelling: Bool?
    public var flowCali: Bool?
    public var vibrationCali: Bool?
    public var layerInspect: Bool?
    public var timelapse: Bool?
    public var useAms: Bool?

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

/// Corps d'édition d'un élément en attente (`PATCH /queue/{id}`, `PrintQueueItemUpdate`). Tous les
/// champs sont optionnels : seuls les champs non `nil` sont encodés et appliqués côté serveur.
public struct QueueItemUpdate: Codable, Sendable, Hashable {
    public var printerId: Int?
    public var scheduledTime: String?
    public var manualStart: Bool?
    public var requirePreviousSuccess: Bool?
    public var autoOffAfter: Bool?
    public var bedLevelling: Bool?
    public var flowCali: Bool?
    public var vibrationCali: Bool?
    public var layerInspect: Bool?
    public var timelapse: Bool?
    public var useAms: Bool?

    public init(
        printerId: Int? = nil,
        scheduledTime: String? = nil,
        manualStart: Bool? = nil,
        requirePreviousSuccess: Bool? = nil,
        autoOffAfter: Bool? = nil,
        bedLevelling: Bool? = nil,
        flowCali: Bool? = nil,
        vibrationCali: Bool? = nil,
        layerInspect: Bool? = nil,
        timelapse: Bool? = nil,
        useAms: Bool? = nil
    ) {
        self.printerId = printerId
        self.scheduledTime = scheduledTime
        self.manualStart = manualStart
        self.requirePreviousSuccess = requirePreviousSuccess
        self.autoOffAfter = autoOffAfter
        self.bedLevelling = bedLevelling
        self.flowCali = flowCali
        self.vibrationCali = vibrationCali
        self.layerInspect = layerInspect
        self.timelapse = timelapse
        self.useAms = useAms
    }
}

/// Corps de mise à jour en lot (`PATCH /queue/bulk`, `PrintQueueBulkUpdate`). Applique les mêmes
/// valeurs à plusieurs éléments en attente. Seuls les champs non `nil` (et `itemIds`) sont encodés.
public struct QueueBulkUpdate: Codable, Sendable, Hashable {
    public var itemIds: [Int]
    public var printerId: Int?
    public var scheduledTime: String?
    public var manualStart: Bool?
    public var requirePreviousSuccess: Bool?
    public var autoOffAfter: Bool?

    public init(
        itemIds: [Int],
        printerId: Int? = nil,
        scheduledTime: String? = nil,
        manualStart: Bool? = nil,
        requirePreviousSuccess: Bool? = nil,
        autoOffAfter: Bool? = nil
    ) {
        self.itemIds = itemIds
        self.printerId = printerId
        self.scheduledTime = scheduledTime
        self.manualStart = manualStart
        self.requirePreviousSuccess = requirePreviousSuccess
        self.autoOffAfter = autoOffAfter
    }
}

/// Réponse d'une mise à jour en lot (`PrintQueueBulkUpdateResponse`).
public struct QueueBulkUpdateResponse: Codable, Sendable, Hashable {
    public var updatedCount: Int
    public var skippedCount: Int
    public var message: String

    public init(updatedCount: Int, skippedCount: Int, message: String) {
        self.updatedCount = updatedCount
        self.skippedCount = skippedCount
        self.message = message
    }
}

/// Un lot d'impression (`GET /queue/batches`, `PrintBatchResponse`) : regroupe les éléments créés
/// en quantité > 1, avec les compteurs dérivés par statut.
public struct PrintBatch: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var quantity: Int
    public var status: String
    public var archiveId: Int?
    public var libraryFileId: Int?
    public var pendingCount: Int
    public var printingCount: Int
    public var completedCount: Int
    public var failedCount: Int
    public var cancelledCount: Int

    public init(
        id: Int,
        name: String,
        quantity: Int,
        status: String,
        archiveId: Int? = nil,
        libraryFileId: Int? = nil,
        pendingCount: Int = 0,
        printingCount: Int = 0,
        completedCount: Int = 0,
        failedCount: Int = 0,
        cancelledCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.status = status
        self.archiveId = archiveId
        self.libraryFileId = libraryFileId
        self.pendingCount = pendingCount
        self.printingCount = printingCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.cancelledCount = cancelledCount
    }

    /// Nombre d'éléments terminés ou annulés (progression du lot).
    public var resolvedCount: Int {
        completedCount + failedCount + cancelledCount
    }
}
