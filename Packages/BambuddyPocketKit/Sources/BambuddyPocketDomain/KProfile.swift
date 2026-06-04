// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Réponse de `GET /printers/{id}/kprofiles/` : profils d'avance de pression (K) stockés sur
/// l'imprimante, plus le diamètre de buse interrogé.
public struct KProfilesResponse: Codable, Sendable, Hashable {
    public var profiles: [KProfile]
    public var nozzleDiameter: String

    public init(profiles: [KProfile], nozzleDiameter: String) {
        self.profiles = profiles
        self.nozzleDiameter = nozzleDiameter
    }
}

/// Un profil de calibration d'avance de pression (K) mémorisé sur l'imprimante.
///
/// Les valeurs numériques `kValue`/`nCoef` sont renvoyées sous forme de **chaînes** par le
/// firmware (préservées telles quelles pour ne pas perdre de précision).
public struct KProfile: Codable, Sendable, Hashable, Identifiable {
    public var slotID: Int
    public var extruderID: Int?
    public var nozzleID: String
    public var nozzleDiameter: String
    public var filamentID: String
    public var name: String
    public var kValue: String
    public var nCoef: String?
    public var amsID: Int?
    public var trayID: Int?
    public var settingID: String?

    /// Identifiant stable pour l'affichage (un slot par profil sur l'imprimante).
    public var id: Int {
        slotID
    }

    public init(
        slotID: Int,
        nozzleID: String,
        nozzleDiameter: String,
        filamentID: String,
        name: String,
        kValue: String
    ) {
        self.slotID = slotID
        self.nozzleID = nozzleID
        self.nozzleDiameter = nozzleDiameter
        self.filamentID = filamentID
        self.name = name
        self.kValue = kValue
    }

    private enum CodingKeys: String, CodingKey {
        case slotID = "slotId"
        case extruderID = "extruderId"
        case nozzleID = "nozzleId"
        case nozzleDiameter
        case filamentID = "filamentId"
        case name
        case kValue
        case nCoef
        case amsID = "amsId"
        case trayID = "trayId"
        case settingID = "settingId"
    }
}

/// Notes utilisateur associées aux profils K (`GET /printers/{id}/kprofiles/notes`).
/// Dictionnaire `setting_id → note`.
public struct KProfileNotes: Codable, Sendable, Hashable {
    public var notes: [String: String]

    public init(notes: [String: String] = [:]) {
        self.notes = notes
    }
}
