// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État d'exécution d'une imprimante virtuelle (sous-objet `status`).
public struct VirtualPrinterStatus: Codable, Sendable, Hashable {
    public var running: Bool?
    public var pendingFiles: Int?

    public init(running: Bool? = nil, pendingFiles: Int? = nil) {
        self.running = running
        self.pendingFiles = pendingFiles
    }
}

/// Imprimante virtuelle (`GET /virtual-printers`) : émulateur de périphérique Bambu utile au
/// développement et aux tests. Le code d'accès n'est jamais renvoyé (`accessCodeSet` seulement).
public struct VirtualPrinter: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var enabled: Bool
    public var mode: String
    public var model: String?
    public var modelName: String?
    public var accessCodeSet: Bool
    public var serial: String?
    public var targetPrinterId: Int?
    public var autoDispatch: Bool
    public var queueForceColorMatch: Bool
    public var bindIp: String?
    public var remoteInterfaceIp: String?
    public var tailscaleDisabled: Bool?
    public var position: Int?
    public var status: VirtualPrinterStatus?

    public init(
        id: Int,
        name: String,
        enabled: Bool = false,
        mode: String = "immediate",
        model: String? = nil,
        modelName: String? = nil,
        accessCodeSet: Bool = false,
        serial: String? = nil,
        targetPrinterId: Int? = nil,
        autoDispatch: Bool = true,
        queueForceColorMatch: Bool = false,
        bindIp: String? = nil,
        remoteInterfaceIp: String? = nil,
        tailscaleDisabled: Bool? = nil,
        position: Int? = nil,
        status: VirtualPrinterStatus? = nil
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.mode = mode
        self.model = model
        self.modelName = modelName
        self.accessCodeSet = accessCodeSet
        self.serial = serial
        self.targetPrinterId = targetPrinterId
        self.autoDispatch = autoDispatch
        self.queueForceColorMatch = queueForceColorMatch
        self.bindIp = bindIp
        self.remoteInterfaceIp = remoteInterfaceIp
        self.tailscaleDisabled = tailscaleDisabled
        self.position = position
        self.status = status
    }

    /// Cette imprimante virtuelle tourne-t-elle ?
    public var isRunning: Bool {
        status?.running ?? false
    }
}

/// Liste d'imprimantes virtuelles + table des modèles disponibles (`GET /virtual-printers`).
public struct VirtualPrinterList: Codable, Sendable, Hashable {
    public var printers: [VirtualPrinter]
    /// Code modèle (`BL-P001`) → nom affichable (`X1C`).
    public var models: [String: String]

    public init(printers: [VirtualPrinter], models: [String: String] = [:]) {
        self.printers = printers
        self.models = models
    }
}

/// Création d'une imprimante virtuelle (`POST /virtual-printers`).
public struct VirtualPrinterCreate: Encodable, Sendable, Hashable {
    public var name: String
    public var enabled: Bool
    public var mode: String
    public var model: String?
    public var accessCode: String?
    public var targetPrinterId: Int?
    public var autoDispatch: Bool
    public var queueForceColorMatch: Bool
    public var bindIp: String?

    public init(
        name: String,
        enabled: Bool = false,
        mode: String = "immediate",
        model: String? = nil,
        accessCode: String? = nil,
        targetPrinterId: Int? = nil,
        autoDispatch: Bool = true,
        queueForceColorMatch: Bool = false,
        bindIp: String? = nil
    ) {
        self.name = name
        self.enabled = enabled
        self.mode = mode
        self.model = model
        self.accessCode = accessCode
        self.targetPrinterId = targetPrinterId
        self.autoDispatch = autoDispatch
        self.queueForceColorMatch = queueForceColorMatch
        self.bindIp = bindIp
    }

    private enum CodingKeys: String, CodingKey {
        case name, enabled, mode, model
        case accessCode = "access_code"
        case targetPrinterId = "target_printer_id"
        case autoDispatch = "auto_dispatch"
        case queueForceColorMatch = "queue_force_color_match"
        case bindIp = "bind_ip"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(accessCode, forKey: .accessCode)
        try container.encodeIfPresent(targetPrinterId, forKey: .targetPrinterId)
        try container.encode(autoDispatch, forKey: .autoDispatch)
        try container.encode(queueForceColorMatch, forKey: .queueForceColorMatch)
        try container.encodeIfPresent(bindIp, forKey: .bindIp)
    }
}

/// Mise à jour partielle d'une imprimante virtuelle (`PUT /virtual-printers/{id}`).
/// Seuls les champs renseignés sont transmis.
public struct VirtualPrinterUpdate: Encodable, Sendable, Hashable {
    public var name: String?
    public var enabled: Bool?
    public var mode: String?
    public var model: String?
    public var accessCode: String?
    public var autoDispatch: Bool?
    public var queueForceColorMatch: Bool?

    public init(
        name: String? = nil,
        enabled: Bool? = nil,
        mode: String? = nil,
        model: String? = nil,
        accessCode: String? = nil,
        autoDispatch: Bool? = nil,
        queueForceColorMatch: Bool? = nil
    ) {
        self.name = name
        self.enabled = enabled
        self.mode = mode
        self.model = model
        self.accessCode = accessCode
        self.autoDispatch = autoDispatch
        self.queueForceColorMatch = queueForceColorMatch
    }

    private enum CodingKeys: String, CodingKey {
        case name, enabled, mode, model
        case accessCode = "access_code"
        case autoDispatch = "auto_dispatch"
        case queueForceColorMatch = "queue_force_color_match"
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(enabled, forKey: .enabled)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(accessCode, forKey: .accessCode)
        try container.encodeIfPresent(autoDispatch, forKey: .autoDispatch)
        try container.encodeIfPresent(queueForceColorMatch, forKey: .queueForceColorMatch)
    }
}
