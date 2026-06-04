// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Clé d'API du serveur (`GET /api-keys/`). Le secret complet n'est **jamais** renvoyé en liste :
/// seul un préfixe (`keyPrefix`) sert à identifier la clé. Le secret complet (`secret`) n'apparaît
/// qu'une seule fois, dans la réponse de **création**.
public struct APIKey: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var keyPrefix: String?
    public var canQueue: Bool?
    public var canControlPrinter: Bool?
    public var canReadStatus: Bool?
    public var canAccessCloud: Bool?
    public var enabled: Bool?
    public var lastUsed: String?
    public var createdAt: String?
    public var expiresAt: String?
    /// Secret complet, présent **uniquement** dans la réponse de création (`POST /api-keys/`).
    public var secret: String?

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case keyPrefix
        case canQueue
        case canControlPrinter
        case canReadStatus
        case canAccessCloud
        case enabled
        case lastUsed
        case createdAt
        case expiresAt
        case secret = "key"
    }

    /// La clé est-elle active (non révoquée) ?
    public var isEnabled: Bool {
        enabled ?? true
    }
}

/// Création d'une clé d'API (`POST /api-keys/`).
public struct APIKeyCreate: Encodable, Sendable, Hashable {
    public var name: String
    public var canQueue: Bool
    public var canControlPrinter: Bool
    public var canReadStatus: Bool
    public var canAccessCloud: Bool

    public init(
        name: String,
        canQueue: Bool = true,
        canControlPrinter: Bool = false,
        canReadStatus: Bool = true,
        canAccessCloud: Bool = false
    ) {
        self.name = name
        self.canQueue = canQueue
        self.canControlPrinter = canControlPrinter
        self.canReadStatus = canReadStatus
        self.canAccessCloud = canAccessCloud
    }
}

/// Mise à jour partielle d'une clé d'API (`PATCH /api-keys/{id}`). Sert notamment à **révoquer**
/// une clé (`enabled = false`). Seuls les champs non-`nil` sont encodés.
public struct APIKeyUpdate: Encodable, Sendable, Hashable {
    public var name: String?
    public var enabled: Bool?
    public var canQueue: Bool?
    public var canControlPrinter: Bool?
    public var canReadStatus: Bool?
    public var canAccessCloud: Bool?

    public init(
        name: String? = nil,
        enabled: Bool? = nil,
        canQueue: Bool? = nil,
        canControlPrinter: Bool? = nil,
        canReadStatus: Bool? = nil,
        canAccessCloud: Bool? = nil
    ) {
        self.name = name
        self.enabled = enabled
        self.canQueue = canQueue
        self.canControlPrinter = canControlPrinter
        self.canReadStatus = canReadStatus
        self.canAccessCloud = canAccessCloud
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case enabled
        case canQueue
        case canControlPrinter
        case canReadStatus
        case canAccessCloud
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(canQueue, forKey: .canQueue)
        try container.encodeIfPresent(canControlPrinter, forKey: .canControlPrinter)
        try container.encodeIfPresent(canReadStatus, forKey: .canReadStatus)
        try container.encodeIfPresent(canAccessCloud, forKey: .canAccessCloud)
    }
}
