// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Un élément de nomenclature (BOM) d'un projet (`GET /projects/{id}/bom`).
public struct BOMItem: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var projectID: Int?
    public var name: String
    public var quantityNeeded: Int?
    public var quantityAcquired: Int?
    public var unitPrice: Double?
    public var sourcingURL: String?
    public var archiveID: Int?
    public var archiveName: String?
    public var stlFilename: String?
    public var remarks: String?
    public var sortOrder: Int?
    public var isComplete: Bool?

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case projectID = "projectId"
        case name
        case quantityNeeded
        case quantityAcquired
        case unitPrice
        case sourcingURL = "sourcingUrl"
        case archiveID = "archiveId"
        case archiveName
        case stlFilename
        case remarks
        case sortOrder
        case isComplete
    }

    /// L'élément est-il marqué comme acquis/terminé ?
    public var complete: Bool {
        isComplete ?? false
    }

    /// Coût total estimé de la ligne (`unitPrice × quantityNeeded`), si connu.
    public var lineTotal: Double? {
        guard let unit = unitPrice else { return nil }
        return unit * Double(quantityNeeded ?? 1)
    }
}

/// Corps de `POST /projects/{id}/bom` (création d'un élément de nomenclature).
public struct BOMItemCreate: Encodable, Sendable, Hashable {
    public var name: String
    public var quantityNeeded: Int
    public var unitPrice: Double?
    public var sourcingURL: String?
    public var remarks: String?

    public init(
        name: String,
        quantityNeeded: Int = 1,
        unitPrice: Double? = nil,
        sourcingURL: String? = nil,
        remarks: String? = nil
    ) {
        self.name = name
        self.quantityNeeded = quantityNeeded
        self.unitPrice = unitPrice
        self.sourcingURL = sourcingURL
        self.remarks = remarks
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case quantityNeeded
        case unitPrice
        case sourcingURL = "sourcingUrl"
        case remarks
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(quantityNeeded, forKey: .quantityNeeded)
        try container.encodeIfPresent(unitPrice, forKey: .unitPrice)
        try container.encodeIfPresent(sourcingURL, forKey: .sourcingURL)
        try container.encodeIfPresent(remarks, forKey: .remarks)
    }
}

/// Corps de `POST /projects/{id}/add-archives` : rattache des archives existantes au projet
/// (`BatchAddArchives`, le serveur pose `project_id` sur chaque archive trouvée).
public struct BatchAddArchives: Encodable, Sendable, Hashable {
    public var archiveIDs: [Int]

    public init(archiveIDs: [Int]) {
        self.archiveIDs = archiveIDs
    }

    private enum CodingKeys: String, CodingKey {
        case archiveIDs = "archive_ids"
    }
}

/// Un événement de la chronologie d'un projet (`GET /projects/{id}/timeline`).
public struct TimelineEvent: Codable, Sendable, Hashable, Identifiable {
    public var eventType: String
    public var timestamp: String
    public var title: String
    public var details: String?

    /// Identifiant stable pour l'affichage (type + horodatage suffisent à distinguer les lignes).
    public var id: String {
        "\(eventType)-\(timestamp)-\(title)"
    }

    public init(eventType: String, timestamp: String, title: String, details: String? = nil) {
        self.eventType = eventType
        self.timestamp = timestamp
        self.title = title
        self.details = details
    }

    private enum CodingKeys: String, CodingKey {
        case eventType
        case timestamp
        case title
        case details = "description"
    }
}
