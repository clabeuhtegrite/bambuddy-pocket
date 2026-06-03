// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Un projet d'impression (`GET /projects/`, `ProjectListResponse`).
public struct Project: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var status: String
    public var details: String?
    public var color: String?
    public var progressPercent: Double?
    public var completedCount: Int?
    public var totalItems: Int?
    public var queueCount: Int?
    public var createdAt: String?

    public init(id: Int, name: String, status: String) {
        self.id = id
        self.name = name
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, status, color, progressPercent, completedCount, totalItems, queueCount, createdAt
        case details = "description"
    }

    /// Progression en fraction (0…1), si connue.
    public var progressFraction: Double? {
        progressPercent.map { min(1, max(0, $0 / 100)) }
    }
}
