// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État de la découverte réseau (`GET /discovery/status`).
public struct DiscoveryStatus: Codable, Sendable, Hashable {
    public var running: Bool?

    public init(running: Bool? = nil) {
        self.running = running
    }

    /// La découverte est-elle en cours ?
    public var isRunning: Bool {
        running ?? false
    }
}

/// Informations sur l'environnement de découverte (`GET /discovery/info`).
public struct DiscoveryInfo: Codable, Sendable, Hashable {
    public var isDocker: Bool?
    public var ssdpRunning: Bool?
    public var scanRunning: Bool?
    public var subnets: [String]?

    public init(
        isDocker: Bool? = nil,
        ssdpRunning: Bool? = nil,
        scanRunning: Bool? = nil,
        subnets: [String]? = nil
    ) {
        self.isDocker = isDocker
        self.ssdpRunning = ssdpRunning
        self.scanRunning = scanRunning
        self.subnets = subnets
    }
}

/// Imprimante découverte sur le réseau (`GET /discovery/printers`).
public struct DiscoveredPrinter: Codable, Sendable, Hashable, Identifiable {
    public var serial: String?
    public var name: String?
    public var ipAddress: String?
    public var model: String?
    public var discoveredAt: String?

    /// Identité stable : numéro de série si présent, sinon adresse IP.
    public var id: String {
        serial ?? ipAddress ?? UUID().uuidString
    }

    public init(serial: String? = nil, name: String? = nil, ipAddress: String? = nil) {
        self.serial = serial
        self.name = name
        self.ipAddress = ipAddress
    }
}
