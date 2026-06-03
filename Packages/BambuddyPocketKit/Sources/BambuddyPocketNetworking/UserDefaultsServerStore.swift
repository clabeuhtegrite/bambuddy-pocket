// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Persiste la liste (non secrète) des serveurs dans `UserDefaults` (les secrets vont au Keychain).
public final class UserDefaultsServerStore: ServerStore, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "bambuddy.servers.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() throws -> [ServerConfiguration] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return try JSONDecoder().decode([ServerConfiguration].self, from: data)
    }

    public func save(_ servers: [ServerConfiguration]) throws {
        let data = try JSONEncoder().encode(servers)
        defaults.set(data, forKey: key)
    }
}
