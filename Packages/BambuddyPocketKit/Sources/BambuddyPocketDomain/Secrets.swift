// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Secrets associés à un serveur (jamais persistés en clair hors Keychain).
public struct ServerSecrets: Codable, Sendable, Hashable {
    /// Clé d'API (`X-API-Key`).
    public var apiKey: String?
    /// JWT obtenu par login (`Authorization: Bearer`).
    public var bearerToken: String?
    /// Cloudflare Access — `CF-Access-Client-Id`.
    public var cloudflareClientID: String?
    /// Cloudflare Access — `CF-Access-Client-Secret`.
    public var cloudflareClientSecret: String?

    public init(
        apiKey: String? = nil,
        bearerToken: String? = nil,
        cloudflareClientID: String? = nil,
        cloudflareClientSecret: String? = nil
    ) {
        self.apiKey = apiKey
        self.bearerToken = bearerToken
        self.cloudflareClientID = cloudflareClientID
        self.cloudflareClientSecret = cloudflareClientSecret
    }

    public var isEmpty: Bool {
        apiKey == nil && bearerToken == nil && cloudflareClientID == nil && cloudflareClientSecret == nil
    }
}

/// Stockage sécurisé des secrets par serveur (impl. Keychain en production).
public protocol SecretStore: Sendable {
    func secrets(for serverID: UUID) throws -> ServerSecrets
    func setSecrets(_ secrets: ServerSecrets, for serverID: UUID) throws
    func deleteSecrets(for serverID: UUID) throws
}

/// Persistance de la liste (non secrète) des serveurs.
public protocol ServerStore: Sendable {
    func load() throws -> [ServerConfiguration]
    func save(_ servers: [ServerConfiguration]) throws
}

/// Implémentation en mémoire de `SecretStore` (tests & previews).
public final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: ServerSecrets] = [:]

    public init() {}

    public func secrets(for serverID: UUID) throws -> ServerSecrets {
        lock.lock()
        defer { lock.unlock() }
        return storage[serverID] ?? ServerSecrets()
    }

    public func setSecrets(_ secrets: ServerSecrets, for serverID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        if secrets.isEmpty {
            storage[serverID] = nil
        } else {
            storage[serverID] = secrets
        }
    }

    public func deleteSecrets(for serverID: UUID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[serverID] = nil
    }
}

/// Implémentation en mémoire de `ServerStore` (tests & previews) : aucune persistance disque.
public final class InMemoryServerStore: ServerStore, @unchecked Sendable {
    private let lock = NSLock()
    private var servers: [ServerConfiguration]

    public init(_ servers: [ServerConfiguration] = []) {
        self.servers = servers
    }

    public func load() throws -> [ServerConfiguration] {
        lock.lock()
        defer { lock.unlock() }
        return servers
    }

    public func save(_ servers: [ServerConfiguration]) throws {
        lock.lock()
        defer { lock.unlock() }
        self.servers = servers
    }
}
