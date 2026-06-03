// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Températures rapportées par l'imprimante (en °C). Tous champs optionnels selon le modèle.
public struct Temperatures: Codable, Sendable, Hashable {
    public var nozzle: Double?
    public var nozzleTarget: Double?
    public var bed: Double?
    public var bedTarget: Double?
    public var chamber: Double?
    public var chamberTarget: Double?

    public init(
        nozzle: Double? = nil,
        nozzleTarget: Double? = nil,
        bed: Double? = nil,
        bedTarget: Double? = nil,
        chamber: Double? = nil,
        chamberTarget: Double? = nil
    ) {
        self.nozzle = nozzle
        self.nozzleTarget = nozzleTarget
        self.bed = bed
        self.bedTarget = bedTarget
        self.chamber = chamber
        self.chamberTarget = chamberTarget
    }
}

/// Niveau de gravité d'une erreur HMS (interprétation de `severity`).
public enum HMSSeverity: Sendable, Hashable {
    case fatal
    case serious
    case common
    case info
    case unknown

    public init(code: Int) {
        switch code {
        case 1: self = .fatal
        case 2: self = .serious
        case 3: self = .common
        case 4: self = .info
        default: self = .unknown
        }
    }
}

/// Erreur HMS (Health Management System) Bambu. Le code se résout en message via une table
/// embarquée (à ajouter en Phase 1) ; `severity` permet de hiérarchiser l'affichage.
public struct HMSError: Codable, Sendable, Hashable, Identifiable {
    public var code: String
    public var attr: Int?
    public var module: Int?
    public var severity: Int?

    public var id: String {
        code
    }

    public var severityLevel: HMSSeverity {
        HMSSeverity(code: severity ?? 0)
    }

    public init(code: String, attr: Int? = nil, module: Int? = nil, severity: Int? = nil) {
        self.code = code
        self.attr = attr
        self.module = module
        self.severity = severity
    }
}

/// Un slot de filament (plateau AMS ou bobine externe).
public struct AMSTray: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var trayColor: String?
    public var trayType: String?
    public var traySubBrands: String?
    public var trayIdName: String?
    public var remain: Int?
    public var tagUid: String?
    public var trayUuid: String?
    public var nozzleTempMin: Int?
    public var nozzleTempMax: Int?
    public var state: Int?

    public init(id: Int) {
        self.id = id
    }
}

/// Une unité AMS (ou AMS-HT). Contient ses plateaux (`tray`).
public struct AMSUnit: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var humidity: Int?
    public var temp: Double?
    public var isAmsHt: Bool?
    public var dryTime: Int?
    public var dryStatus: Int?
    public var moduleType: String?
    public var serialNumber: String?
    public var swVer: String?
    public var tray: [AMSTray]?

    public init(id: Int) {
        self.id = id
    }
}

/// État temps réel d'une imprimante (cf. `docs/bambuddy-api.md` §5.1).
///
/// Sur-ensemble REST (`GET /printers/{id}/status`) ; le WebSocket pousse un **sous-ensemble**
/// (les champs absents restent `nil`). Tous les champs sont optionnels pour permettre la
/// **fusion** des deltas WebSocket et la tolérance aux évolutions de l'API.
public struct PrinterStatus: Codable, Sendable, Hashable {
    public var name: String?
    public var model: String?
    public var connected: Bool?
    public var state: PrinterState?

    // Impression en cours
    public var currentPrint: String?
    public var subtaskName: String?
    public var gcodeFile: String?
    public var progress: Double?
    public var remainingTime: Int?
    public var layerNum: Int?
    public var totalLayers: Int?
    public var coverUrl: String?
    public var currentArchiveId: Int?
    public var currentPlateId: Int?

    // Capteurs
    public var temperatures: Temperatures?
    public var hmsErrors: [HMSError]?
    public var ams: [AMSUnit]?
    public var vtTray: [AMSTray]?
    public var wifiSignal: Int?
    public var wiredNetwork: Bool?
    public var doorOpen: Bool?

    // Ventilateurs
    public var coolingFanSpeed: Int?
    public var bigFan1Speed: Int?
    public var bigFan2Speed: Int?
    public var heatbreakFanSpeed: Int?

    // Divers
    public var chamberLight: Bool?
    public var activeExtruder: Int?
    public var speedLevel: Int?
    public var stgCur: Int?
    public var stgCurName: String?
    public var printableObjectsCount: Int?
    public var awaitingPlateClear: Bool?
    public var supportsDrying: Bool?
    public var firmwareVersion: String?
    public var sdcard: Bool?
    public var timelapse: Bool?
    public var ipcam: Bool?

    public init() {}

    // MARK: Helpers UI

    /// Une impression est-elle active (en cours / préparation / pause) ?
    public var isPrinting: Bool {
        state?.isActivePrint ?? false
    }

    /// Progression en fraction (0…1) si disponible.
    public var progressFraction: Double? {
        progress.map { max(0, min(1, $0 / 100)) }
    }

    /// L'imprimante signale-t-elle au moins une erreur HMS ?
    public var hasActiveErrors: Bool {
        !(hmsErrors ?? []).isEmpty
    }

    /// Erreur HMS la plus grave (pour mise en avant).
    public var mostSevereError: HMSError? {
        hmsErrors?.min { lhs, rhs in (lhs.severity ?? 99) < (rhs.severity ?? 99) }
    }
}
