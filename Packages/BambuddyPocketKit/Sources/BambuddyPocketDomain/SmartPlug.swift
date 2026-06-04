// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Prise connectée pilotant l'alimentation d'une imprimante (`GET /smart-plugs/`). Sous-ensemble
/// robuste des champs utiles à l'app : identité, type, imprimante liée, activation, dernier état.
public struct SmartPlug: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var plugType: String?
    public var printerID: Int?
    public var enabled: Bool?
    public var lastState: String?
    public var ipAddress: String?

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case plugType
        case printerID = "printerId"
        case enabled
        case lastState
        case ipAddress
    }

    /// La prise est-elle active (non désactivée) ?
    public var isEnabled: Bool {
        enabled ?? true
    }
}

/// Action de pilotage d'une prise (`POST /smart-plugs/{id}/control`).
public enum SmartPlugAction: String, Codable, Sendable, Hashable, CaseIterable {
    case on
    case off
    case toggle
}

/// Corps de `POST /smart-plugs/{id}/control`.
public struct SmartPlugControl: Encodable, Sendable, Hashable {
    public var action: SmartPlugAction

    public init(action: SmartPlugAction) {
        self.action = action
    }
}

/// Consommation rapportée par la prise.
public struct SmartPlugEnergy: Codable, Sendable, Hashable {
    public var power: Double?
    public var voltage: Double?
    public var current: Double?
    public var today: Double?
    public var total: Double?

    public init(
        power: Double? = nil,
        voltage: Double? = nil,
        current: Double? = nil,
        today: Double? = nil,
        total: Double? = nil
    ) {
        self.power = power
        self.voltage = voltage
        self.current = current
        self.today = today
        self.total = total
    }
}

/// État temps réel d'une prise (`GET /smart-plugs/{id}/status`).
public struct SmartPlugStatus: Codable, Sendable, Hashable {
    public var state: String?
    public var reachable: Bool?
    public var deviceName: String?
    public var energy: SmartPlugEnergy?

    public init(
        state: String? = nil,
        reachable: Bool? = nil,
        deviceName: String? = nil,
        energy: SmartPlugEnergy? = nil
    ) {
        self.state = state
        self.reachable = reachable
        self.deviceName = deviceName
        self.energy = energy
    }

    /// La prise est-elle joignable ?
    public var isReachable: Bool {
        reachable ?? false
    }

    /// La prise alimente-t-elle (état « on ») ? `nil` si l'état est inconnu.
    public var isOn: Bool? {
        guard let state else {
            return nil
        }
        switch state.lowercased() {
        case "on", "true", "1": return true
        case "off", "false", "0": return false
        default: return nil
        }
    }
}
