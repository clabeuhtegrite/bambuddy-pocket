// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Une imprimante telle que listée par l'API (`GET /printers/`).
///
/// ⚠️ Le champ `access_code` (secret LAN Bambu) est **volontairement non modélisé** :
/// l'app ne le stocke ni ne l'affiche jamais.
public struct Printer: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var model: String?
    public var location: String?
    public var ipAddress: String?
    public var serialNumber: String?
    public var isActive: Bool?
    public var nozzleCount: Int?
    public var autoArchive: Bool?
    public var externalCameraEnabled: Bool?

    public init(
        id: Int,
        name: String,
        model: String? = nil,
        location: String? = nil,
        ipAddress: String? = nil,
        serialNumber: String? = nil,
        isActive: Bool? = nil,
        nozzleCount: Int? = nil,
        autoArchive: Bool? = nil,
        externalCameraEnabled: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.location = location
        self.ipAddress = ipAddress
        self.serialNumber = serialNumber
        self.isActive = isActive
        self.nozzleCount = nozzleCount
        self.autoArchive = autoArchive
        self.externalCameraEnabled = externalCameraEnabled
    }
}
