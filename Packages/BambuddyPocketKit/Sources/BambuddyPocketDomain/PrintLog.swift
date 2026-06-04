// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Entrée du journal d'impression (`GET /print-log/`). Table indépendante des archives :
/// elle survit à la suppression d'une archive et au vidage de la file.
///
/// Les dates sont conservées en `String` : le serveur émet de l'ISO-8601 **sans fuseau**
/// (p. ex. `2026-06-04T11:37:08`), incompatible avec le décodage `Date` strict — le formatage
/// localisé est délégué à la couche présentation (robuste au fuseau manquant).
public struct PrintLogEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var archiveID: Int?
    public var printName: String?
    public var printerName: String?
    public var printerID: Int?
    public var status: String
    public var startedAt: String?
    public var completedAt: String?
    public var durationSeconds: Int?
    public var filamentType: String?
    public var filamentColor: String?
    public var filamentUsedGrams: Double?
    public var failureReason: String?
    public var thumbnailPath: String?
    public var createdByUsername: String?
    public var createdAt: String?

    public init(
        id: Int,
        archiveID: Int? = nil,
        printName: String? = nil,
        printerName: String? = nil,
        printerID: Int? = nil,
        status: String,
        startedAt: String? = nil,
        completedAt: String? = nil,
        durationSeconds: Int? = nil,
        filamentType: String? = nil,
        filamentColor: String? = nil,
        filamentUsedGrams: Double? = nil,
        failureReason: String? = nil,
        thumbnailPath: String? = nil,
        createdByUsername: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.archiveID = archiveID
        self.printName = printName
        self.printerName = printerName
        self.printerID = printerID
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.filamentType = filamentType
        self.filamentColor = filamentColor
        self.filamentUsedGrams = filamentUsedGrams
        self.failureReason = failureReason
        self.thumbnailPath = thumbnailPath
        self.createdByUsername = createdByUsername
        self.createdAt = createdAt
    }
}

/// Page du journal d'impression (`GET /print-log/`).
public struct PrintLogPage: Codable, Sendable, Hashable {
    public var items: [PrintLogEntry]
    public var total: Int

    public init(items: [PrintLogEntry], total: Int) {
        self.items = items
        self.total = total
    }
}
