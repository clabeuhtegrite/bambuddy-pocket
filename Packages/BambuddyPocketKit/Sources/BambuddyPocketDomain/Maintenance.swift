// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Vue d'ensemble de la maintenance d'une imprimante (`GET /maintenance/overview`).
public struct MaintenanceOverview: Codable, Sendable, Hashable, Identifiable {
    public var printerID: Int
    public var printerName: String?
    public var printerModel: String?
    public var totalPrintHours: Double?
    public var maintenanceItems: [MaintenanceItem]?

    public var id: Int {
        printerID
    }

    public init(printerID: Int, printerName: String? = nil) {
        self.printerID = printerID
        self.printerName = printerName
    }

    private enum CodingKeys: String, CodingKey {
        case printerID = "printerId"
        case printerName
        case printerModel
        case totalPrintHours
        case maintenanceItems
    }

    /// Items en retard (à effectuer en priorité).
    public var dueItems: [MaintenanceItem] {
        (maintenanceItems ?? []).filter(\.isDueNow)
    }
}

/// Élément de maintenance suivi pour une imprimante (intervalle, échéance, état).
public struct MaintenanceItem: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var maintenanceTypeName: String?
    public var maintenanceTypeIcon: String?
    public var enabled: Bool?
    public var intervalHours: Double?
    public var intervalType: String?
    public var hoursUntilDue: Double?
    public var daysUntilDue: Double?
    public var isDue: Bool?
    public var isWarning: Bool?
    public var lastPerformedAt: String?

    public init(id: Int) {
        self.id = id
    }

    /// L'item est-il en retard (à effectuer maintenant) ?
    public var isDueNow: Bool {
        isDue ?? false
    }

    /// L'item approche-t-il de son échéance (avertissement) ?
    public var isWarningNow: Bool {
        isWarning ?? false
    }
}

/// Corps de `POST /maintenance/items/{id}/perform` (notes facultatives).
public struct PerformMaintenance: Encodable, Sendable, Hashable {
    public var notes: String?

    public init(notes: String? = nil) {
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case notes
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}
