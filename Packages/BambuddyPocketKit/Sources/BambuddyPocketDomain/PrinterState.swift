// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État de haut niveau d'une imprimante, tel que renvoyé par l'API (`state`).
/// Tolérant aux valeurs inconnues (forward-compatibilité) via `.unknown`.
public enum PrinterState: Sendable, Hashable {
    case idle
    case prepare
    case running
    case pause
    case finish
    case failed
    case slicing
    case unknown(String)

    public init(apiValue: String) {
        switch apiValue.uppercased() {
        case "IDLE": self = .idle
        case "PREPARE": self = .prepare
        case "RUNNING": self = .running
        case "PAUSE": self = .pause
        case "FINISH": self = .finish
        case "FAILED": self = .failed
        case "SLICING": self = .slicing
        default: self = .unknown(apiValue)
        }
    }

    /// Valeur brute telle qu'attendue par l'API.
    public var apiValue: String {
        switch self {
        case .idle: "IDLE"
        case .prepare: "PREPARE"
        case .running: "RUNNING"
        case .pause: "PAUSE"
        case .finish: "FINISH"
        case .failed: "FAILED"
        case .slicing: "SLICING"
        case let .unknown(value): value
        }
    }

    /// Une impression est-elle active (en cours, préparation ou pause) ?
    public var isActivePrint: Bool {
        self == .running || self == .prepare || self == .pause
    }
}

extension PrinterState: Codable {
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self.init(apiValue: raw)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(apiValue)
    }
}
