// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État du journal de débogage du serveur (`GET`/`POST /support/debug-logging`).
public struct DebugLoggingState: Codable, Sendable, Hashable {
    public var enabled: Bool
    public var enabledAt: String?
    public var durationSeconds: Int?

    public init(enabled: Bool = false, enabledAt: String? = nil, durationSeconds: Int? = nil) {
        self.enabled = enabled
        self.enabledAt = enabledAt
        self.durationSeconds = durationSeconds
    }
}

/// Entrée du journal applicatif du serveur (`GET /support/logs`).
public struct LogEntry: Codable, Sendable, Hashable, Identifiable {
    public var timestamp: String?
    public var level: String?
    public var loggerName: String?
    public var message: String?

    /// Identifiant stable dérivé du contenu (les entrées n'ont pas d'identifiant serveur).
    public var id: Int {
        var hasher = Hasher()
        hasher.combine(timestamp)
        hasher.combine(level)
        hasher.combine(loggerName)
        hasher.combine(message)
        return hasher.finalize()
    }

    public init(timestamp: String? = nil, level: String? = nil, loggerName: String? = nil, message: String? = nil) {
        self.timestamp = timestamp
        self.level = level
        self.loggerName = loggerName
        self.message = message
    }
}

/// Réponse paginée du journal applicatif (`GET /support/logs`).
public struct LogsResponse: Codable, Sendable, Hashable {
    public var entries: [LogEntry]
    public var totalInFile: Int
    public var filteredCount: Int

    public init(entries: [LogEntry], totalInFile: Int = 0, filteredCount: Int = 0) {
        self.entries = entries
        self.totalInFile = totalInFile
        self.filteredCount = filteredCount
    }
}
