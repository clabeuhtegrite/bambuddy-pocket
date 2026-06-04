// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Lien externe personnalisé du serveur (`GET /external-links/`) : raccourci vers une ressource
/// web (wiki, documentation, boutique…).
public struct ExternalLink: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var url: String
    public var icon: String?
    public var sortOrder: Int?

    public init(id: Int, name: String, url: String) {
        self.id = id
        self.name = name
        self.url = url
    }

    /// URL exploitable, ou `nil` si la chaîne n'est pas une URL valide.
    public var resolvedURL: URL? {
        URL(string: url)
    }
}

/// Création d'un lien externe (`POST /external-links/`).
public struct ExternalLinkCreate: Encodable, Sendable, Hashable {
    public var name: String
    public var url: String
    public var icon: String?

    public init(name: String, url: String, icon: String? = nil) {
        self.name = name
        self.url = url
        self.icon = icon
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case url
        case icon
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encodeIfPresent(icon, forKey: .icon)
    }
}
