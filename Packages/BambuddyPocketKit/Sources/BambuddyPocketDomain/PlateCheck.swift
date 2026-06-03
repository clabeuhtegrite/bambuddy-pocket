// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Résultat d'une détection de plateau vide par vision (`GET /printers/{id}/camera/check-plate`).
///
/// Sous-ensemble robuste : champs non modélisés ignorés. La détection compare l'image courante à
/// une référence calibrée du plateau vide ; la lumière de chambre doit être allumée pour être fiable.
public struct PlateCheck: Codable, Sendable, Hashable {
    public var isEmpty: Bool
    public var confidence: Double
    public var differencePercent: Double?
    public var message: String?
    public var needsCalibration: Bool?
    public var lightWarning: Bool?
    public var referenceCount: Int?
    public var maxReferences: Int?

    public init(isEmpty: Bool, confidence: Double) {
        self.isEmpty = isEmpty
        self.confidence = confidence
    }

    /// Confiance en pourcentage (0…100), bornée.
    public var confidencePercent: Int {
        Int((min(1, max(0, confidence)) * 100).rounded())
    }
}

/// État d'un flux caméra (`GET /printers/{id}/camera/status`) : actif, dernière image, stagnation.
public struct CameraStatus: Codable, Sendable, Hashable {
    public var active: Bool
    public var hasFrames: Bool
    public var stalled: Bool
    public var secondsSinceFrame: Double?
    public var streamUptime: Double?

    public init(active: Bool, hasFrames: Bool, stalled: Bool) {
        self.active = active
        self.hasFrames = hasFrames
        self.stalled = stalled
    }
}

/// Jeton réutilisable d'accès au flux/snapshot caméra (`POST /printers/camera/stream-token`).
public struct CameraStreamToken: Codable, Sendable, Hashable {
    public var token: String

    public init(token: String) {
        self.token = token
    }
}
