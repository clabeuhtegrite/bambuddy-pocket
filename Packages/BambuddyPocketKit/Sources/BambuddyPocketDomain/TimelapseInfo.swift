// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Métadonnées d'une vidéo timelapse d'archive (`GET /archives/{id}/timelapse/info`).
public struct TimelapseInfo: Codable, Sendable, Hashable {
    public var duration: Double?
    public var width: Int?
    public var height: Int?
    public var fps: Double?
    public var codec: String?
    public var fileSize: Int?
    public var hasAudio: Bool?

    public init(
        duration: Double? = nil,
        width: Int? = nil,
        height: Int? = nil,
        fps: Double? = nil,
        codec: String? = nil,
        fileSize: Int? = nil,
        hasAudio: Bool? = nil
    ) {
        self.duration = duration
        self.width = width
        self.height = height
        self.fps = fps
        self.codec = codec
        self.fileSize = fileSize
        self.hasAudio = hasAudio
    }

    /// Résolution « L × H » si les deux dimensions sont connues.
    public var resolution: String? {
        guard let width, let height else { return nil }
        return "\(width) × \(height)"
    }
}
