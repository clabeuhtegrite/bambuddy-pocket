// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Un objet imprimable de la plaque courante (`GET /printers/{id}/print/objects`).
///
/// Permet la fonction « ignorer des objets » : chaque objet a un identifiant, un nom, une position
/// approximative sur la plaque et un drapeau indiquant s'il est déjà ignoré.
public struct PrintObject: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var x: Double?
    public var y: Double?
    public var skipped: Bool

    public init(id: Int, name: String, x: Double? = nil, y: Double? = nil, skipped: Bool = false) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.skipped = skipped
    }
}

/// Réponse de `GET /printers/{id}/print/objects` : objets de la plaque + métadonnées.
public struct PrintObjects: Codable, Sendable, Hashable {
    public var objects: [PrintObject]
    public var total: Int
    public var skippedCount: Int
    public var isPrinting: Bool

    public init(objects: [PrintObject] = [], total: Int = 0, skippedCount: Int = 0, isPrinting: Bool = false) {
        self.objects = objects
        self.total = total
        self.skippedCount = skippedCount
        self.isPrinting = isPrinting
    }
}

/// Drapeaux de calibration pour `POST /printers/{id}/calibration` (paramètres de requête).
public struct CalibrationOptions: Sendable, Hashable {
    public var bedLeveling: Bool
    public var vibration: Bool
    public var motorNoise: Bool
    public var nozzleOffset: Bool
    public var highTempHeatbed: Bool

    public init(
        bedLeveling: Bool = false,
        vibration: Bool = false,
        motorNoise: Bool = false,
        nozzleOffset: Bool = false,
        highTempHeatbed: Bool = false
    ) {
        self.bedLeveling = bedLeveling
        self.vibration = vibration
        self.motorNoise = motorNoise
        self.nozzleOffset = nozzleOffset
        self.highTempHeatbed = highTempHeatbed
    }

    /// Au moins un type de calibration est sélectionné.
    public var hasSelection: Bool {
        bedLeveling || vibration || motorNoise || nozzleOffset || highTempHeatbed
    }

    /// Sérialise les drapeaux en paramètres de requête pour l'endpoint de calibration.
    public var queryString: String {
        "bed_leveling=\(bedLeveling)&vibration=\(vibration)&motor_noise=\(motorNoise)"
            + "&nozzle_offset=\(nozzleOffset)&high_temp_heatbed=\(highTempHeatbed)"
    }
}
