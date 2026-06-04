// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État du système de sauvegarde locale (`GET /local-backup/status`).
public struct BackupStatus: Codable, Sendable, Hashable {
    public var isRunning: Bool?
    public var enabled: Bool?
    public var schedule: String?
    public var time: String?
    public var retention: Int?
    public var lastBackupAt: String?
    public var lastStatus: String?
    public var nextRun: String?

    public init(
        isRunning: Bool? = nil,
        enabled: Bool? = nil,
        schedule: String? = nil,
        time: String? = nil,
        retention: Int? = nil,
        lastBackupAt: String? = nil,
        lastStatus: String? = nil,
        nextRun: String? = nil
    ) {
        self.isRunning = isRunning
        self.enabled = enabled
        self.schedule = schedule
        self.time = time
        self.retention = retention
        self.lastBackupAt = lastBackupAt
        self.lastStatus = lastStatus
        self.nextRun = nextRun
    }

    /// Les sauvegardes planifiées sont-elles actives ?
    public var isScheduleEnabled: Bool {
        enabled ?? false
    }
}

/// Fichier de sauvegarde locale (`GET /local-backup/backups`).
public struct BackupFile: Codable, Sendable, Hashable, Identifiable {
    public var filename: String
    public var size: Int?
    public var createdAt: String?

    public var id: String {
        filename
    }

    public init(filename: String, size: Int? = nil, createdAt: String? = nil) {
        self.filename = filename
        self.size = size
        self.createdAt = createdAt
    }

    /// Taille lisible (« 38,6 Ko »), ou `nil` si inconnue.
    public var formattedSize: String? {
        guard let size else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

/// Réponse d'un déclenchement de sauvegarde (`POST /local-backup/run`).
public struct BackupRunResult: Codable, Sendable, Hashable {
    public var success: Bool?
    public var message: String?
    public var filename: String?

    public init(success: Bool? = nil, message: String? = nil, filename: String? = nil) {
        self.success = success
        self.message = message
        self.filename = filename
    }
}
