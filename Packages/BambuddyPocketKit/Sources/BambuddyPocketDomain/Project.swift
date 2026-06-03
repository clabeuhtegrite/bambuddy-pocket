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
    public var targetCount: Int?
    public var notes: String?
    public var tags: String?
    public var priority: String?
    public var budget: Double?
    public var url: String?

    public init(id: Int, name: String, status: String) {
        self.id = id
        self.name = name
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, status, color, progressPercent, completedCount, totalItems, queueCount, createdAt
        case targetCount, notes, tags, priority, budget, url
        case details = "description"
    }

    /// Progression en fraction (0…1), si connue.
    public var progressFraction: Double? {
        progressPercent.map { min(1, max(0, $0 / 100)) }
    }
}

/// Corps de création d'un projet (`POST /projects/`, `ProjectCreate`).
public struct ProjectCreate: Codable, Sendable, Hashable {
    public var name: String
    public var description: String?
    public var color: String?
    public var targetCount: Int?
    public var notes: String?
    public var tags: String?
    public var priority: String
    public var budget: Double?
    public var url: String?

    public init(
        name: String,
        description: String? = nil,
        color: String? = nil,
        targetCount: Int? = nil,
        notes: String? = nil,
        tags: String? = nil,
        priority: String = "normal",
        budget: Double? = nil,
        url: String? = nil
    ) {
        self.name = name
        self.description = description
        self.color = color
        self.targetCount = targetCount
        self.notes = notes
        self.tags = tags
        self.priority = priority
        self.budget = budget
        self.url = url
    }
}

/// Corps d'édition d'un projet (`PATCH /projects/{id}`, `ProjectUpdate`). Champs optionnels : seuls
/// les champs non `nil` sont encodés (et donc appliqués via `exclude_unset`).
public struct ProjectUpdate: Codable, Sendable, Hashable {
    public var name: String?
    public var description: String?
    public var color: String?
    public var status: String?
    public var targetCount: Int?
    public var notes: String?
    public var tags: String?
    public var priority: String?
    public var budget: Double?
    public var url: String?

    public init(
        name: String? = nil,
        description: String? = nil,
        color: String? = nil,
        status: String? = nil,
        targetCount: Int? = nil,
        notes: String? = nil,
        tags: String? = nil,
        priority: String? = nil,
        budget: Double? = nil,
        url: String? = nil
    ) {
        self.name = name
        self.description = description
        self.color = color
        self.status = status
        self.targetCount = targetCount
        self.notes = notes
        self.tags = tags
        self.priority = priority
        self.budget = budget
        self.url = url
    }
}
