// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Mise à jour partielle d'une imprimante côté serveur (`PATCH /printers/{id}`, `PrinterUpdate`).
///
/// Tous les champs sont optionnels : seuls les champs non `nil` sont encodés (l'encodeur synthétisé
/// omet les optionnels `nil`), ce qui correspond au `exclude_unset` du serveur — les champs laissés
/// `nil` ne sont pas modifiés. `accessCode` est le secret LAN Bambu : transmis au serveur mais
/// jamais persisté ni réaffiché par l'app.
public struct PrinterUpdate: Codable, Sendable, Hashable {
    public var name: String?
    public var ipAddress: String?
    public var accessCode: String?
    public var model: String?
    public var location: String?
    public var isActive: Bool?
    public var autoArchive: Bool?

    public init(
        name: String? = nil,
        ipAddress: String? = nil,
        accessCode: String? = nil,
        model: String? = nil,
        location: String? = nil,
        isActive: Bool? = nil,
        autoArchive: Bool? = nil
    ) {
        self.name = name
        self.ipAddress = ipAddress
        self.accessCode = accessCode
        self.model = model
        self.location = location
        self.isActive = isActive
        self.autoArchive = autoArchive
    }
}
