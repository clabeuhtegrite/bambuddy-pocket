// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Données de création d'une imprimante côté serveur (`POST /printers/`, `PrinterCreate`).
///
/// `accessCode` est le secret LAN Bambu : il est **transmis au serveur** qui le stocke, mais
/// **jamais persisté ni réaffiché** par l'app (cf. `Printer`).
public struct PrinterCreate: Codable, Sendable, Hashable {
    public var name: String
    public var serialNumber: String
    public var ipAddress: String
    public var accessCode: String
    public var model: String?
    public var location: String?

    public init(
        name: String,
        serialNumber: String,
        ipAddress: String,
        accessCode: String,
        model: String? = nil,
        location: String? = nil
    ) {
        self.name = name
        self.serialNumber = serialNumber
        self.ipAddress = ipAddress
        self.accessCode = accessCode
        self.model = model
        self.location = location
    }
}
