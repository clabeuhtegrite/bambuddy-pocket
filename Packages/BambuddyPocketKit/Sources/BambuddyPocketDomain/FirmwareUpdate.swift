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
    /// URL de téléchargement de la dernière version (informatif : l'app **n'effectue pas** la mise à
    /// jour, elle affiche seulement l'information fournie par le cloud Bambu).
    public var downloadUrl: String?
    /// Catalogue complet des versions disponibles (récentes en premier), chacune avec ses notes.
    public var availableVersions: [FirmwareVersion]?

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
        case downloadUrl
        case availableVersions
    }

    /// Une mise à jour est-elle disponible ?
    public var isUpdateAvailable: Bool {
        updateAvailable ?? false
    }

    /// Versions disponibles, dédupliquées et triées (les plus récentes en tête, comme le cloud).
    public var versions: [FirmwareVersion] {
        availableVersions ?? []
    }
}

/// Une version de firmware proposée par le cloud Bambu (`available_versions[]`). Lecture seule :
/// l'app affiche la version, sa disponibilité de fichier et ses notes — elle ne déclenche aucune MAJ.
public struct FirmwareVersion: Codable, Sendable, Hashable, Identifiable {
    public var version: String
    public var fileAvailable: Bool?
    public var downloadUrl: String?
    public var releaseNotes: String?
    public var releaseTime: String?

    public var id: String {
        version
    }

    public init(
        version: String,
        fileAvailable: Bool? = nil,
        downloadUrl: String? = nil,
        releaseNotes: String? = nil,
        releaseTime: String? = nil
    ) {
        self.version = version
        self.fileAvailable = fileAvailable
        self.downloadUrl = downloadUrl
        self.releaseNotes = releaseNotes
        self.releaseTime = releaseTime
    }

    /// Le fichier de cette version est-il téléchargeable côté cloud ?
    public var hasFile: Bool {
        fileAvailable ?? false
    }
}
