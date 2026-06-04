// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Réponse de `GET /firmware/updates` : disponibilité de mise à jour firmware par imprimante.
public struct FirmwareUpdates: Codable, Sendable, Hashable {
    public var updates: [FirmwareUpdate]?

    public init(updates: [FirmwareUpdate]? = nil) {
        self.updates = updates
    }

    /// Nombre d'imprimantes avec une mise à jour disponible.
    public var availableCount: Int {
        (updates ?? []).filter(\.isUpdateAvailable).count
    }
}

/// État de mise à jour firmware d'une imprimante (version courante vs dernière).
public struct FirmwareUpdate: Codable, Sendable, Hashable, Identifiable {
    public var printerID: Int
    public var printerName: String?
    public var model: String?
    public var currentVersion: String?
    public var latestVersion: String?
    public var updateAvailable: Bool?
    public var releaseNotes: String?

    public var id: Int {
        printerID
    }

    public init(printerID: Int) {
        self.printerID = printerID
    }

    private enum CodingKeys: String, CodingKey {
        case printerID = "printerId"
        case printerName
        case model
        case currentVersion
        case latestVersion
        case updateAvailable
        case releaseNotes
    }

    /// Une mise à jour est-elle disponible ?
    public var isUpdateAvailable: Bool {
        updateAvailable ?? false
    }
}
