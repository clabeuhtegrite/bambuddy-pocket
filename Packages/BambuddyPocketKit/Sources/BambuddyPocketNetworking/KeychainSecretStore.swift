// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation
import Security

public enum KeychainError: Error, Sendable, Equatable {
    case unexpectedStatus(OSStatus)
}

/// Implémentation `SecretStore` adossée au Keychain iOS.
///
/// Un item `kSecClassGenericPassword` par serveur (account = `serverID`), valeur = JSON des
/// `ServerSecrets`. Accessibilité `AfterFirstUnlockThisDeviceOnly` (pas de synchro iCloud).
public final class KeychainSecretStore: SecretStore, @unchecked Sendable {
    private let service: String

    public init(service: String = "app.bambuddy.pocket.secrets") {
        self.service = service
    }

    private func baseQuery(for serverID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: serverID.uuidString
        ]
    }

    public func secrets(for serverID: UUID) throws -> ServerSecrets {
        var query = baseQuery(for: serverID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return ServerSecrets()
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw KeychainError.unexpectedStatus(status)
        }
        return try JSONDecoder().decode(ServerSecrets.self, from: data)
    }

    public func setSecrets(_ secrets: ServerSecrets, for serverID: UUID) throws {
        // Upsert simple : on supprime puis on ré-ajoute.
        SecItemDelete(baseQuery(for: serverID) as CFDictionary)
        guard !secrets.isEmpty else { return }

        let data = try JSONEncoder().encode(secrets)
        var attributes = baseQuery(for: serverID)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func deleteSecrets(for serverID: UUID) throws {
        let status = SecItemDelete(baseQuery(for: serverID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
