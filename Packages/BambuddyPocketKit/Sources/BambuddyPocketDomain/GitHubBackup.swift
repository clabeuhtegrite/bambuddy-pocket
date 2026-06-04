// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État courant de la sauvegarde distante Git (`GET /github-backup/status`).
public struct GitHubBackupStatus: Codable, Sendable, Hashable {
    public var configured: Bool
    public var enabled: Bool
    public var isRunning: Bool
    public var progress: String?
    public var lastBackupAt: String?
    public var lastBackupStatus: String?
    public var nextScheduledRun: String?

    public init(
        configured: Bool = false,
        enabled: Bool = false,
        isRunning: Bool = false,
        progress: String? = nil,
        lastBackupAt: String? = nil,
        lastBackupStatus: String? = nil,
        nextScheduledRun: String? = nil
    ) {
        self.configured = configured
        self.enabled = enabled
        self.isRunning = isRunning
        self.progress = progress
        self.lastBackupAt = lastBackupAt
        self.lastBackupStatus = lastBackupStatus
        self.nextScheduledRun = nextScheduledRun
    }
}

/// Configuration de la sauvegarde distante Git (`GET /github-backup/config`, peut être `null`).
/// Le jeton d'accès n'est jamais renvoyé : seul `hasToken` indique sa présence.
public struct GitHubBackupConfig: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var repositoryUrl: String
    public var hasToken: Bool
    public var branch: String
    public var provider: String
    public var allowInsecureHttp: Bool
    public var scheduleEnabled: Bool
    public var scheduleType: String
    public var backupKprofiles: Bool
    public var backupCloudProfiles: Bool
    public var backupSettings: Bool
    public var backupSpools: Bool
    public var backupArchives: Bool
    public var enabled: Bool
    public var lastBackupAt: String?
    public var lastBackupStatus: String?
    public var lastBackupMessage: String?
    public var lastBackupCommitSha: String?
    public var nextScheduledRun: String?

    public init(
        id: Int,
        repositoryUrl: String,
        hasToken: Bool = false,
        branch: String = "main",
        provider: String = "github",
        allowInsecureHttp: Bool = false,
        scheduleEnabled: Bool = false,
        scheduleType: String = "daily",
        backupKprofiles: Bool = true,
        backupCloudProfiles: Bool = true,
        backupSettings: Bool = false,
        backupSpools: Bool = false,
        backupArchives: Bool = false,
        enabled: Bool = true,
        lastBackupAt: String? = nil,
        lastBackupStatus: String? = nil,
        lastBackupMessage: String? = nil,
        lastBackupCommitSha: String? = nil,
        nextScheduledRun: String? = nil
    ) {
        self.id = id
        self.repositoryUrl = repositoryUrl
        self.hasToken = hasToken
        self.branch = branch
        self.provider = provider
        self.allowInsecureHttp = allowInsecureHttp
        self.scheduleEnabled = scheduleEnabled
        self.scheduleType = scheduleType
        self.backupKprofiles = backupKprofiles
        self.backupCloudProfiles = backupCloudProfiles
        self.backupSettings = backupSettings
        self.backupSpools = backupSpools
        self.backupArchives = backupArchives
        self.enabled = enabled
        self.lastBackupAt = lastBackupAt
        self.lastBackupStatus = lastBackupStatus
        self.lastBackupMessage = lastBackupMessage
        self.lastBackupCommitSha = lastBackupCommitSha
        self.nextScheduledRun = nextScheduledRun
    }
}

/// Entrée du journal de sauvegarde Git (`GET /github-backup/logs`).
public struct GitHubBackupLog: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var configId: Int
    public var startedAt: String?
    public var completedAt: String?
    public var status: String
    public var trigger: String
    public var commitSha: String?
    public var filesChanged: Int
    public var errorMessage: String?

    public init(
        id: Int,
        configId: Int,
        startedAt: String? = nil,
        completedAt: String? = nil,
        status: String,
        trigger: String,
        commitSha: String? = nil,
        filesChanged: Int = 0,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.configId = configId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.status = status
        self.trigger = trigger
        self.commitSha = commitSha
        self.filesChanged = filesChanged
        self.errorMessage = errorMessage
    }
}

/// Corps de création/mise à jour d'une configuration de sauvegarde Git (`POST /github-backup/config`).
/// N'inclut le jeton que lorsque l'utilisateur en saisit un (stocké au Keychain côté app).
public struct GitHubBackupConfigCreate: Codable, Sendable, Hashable {
    public var repositoryUrl: String
    public var accessToken: String?
    public var branch: String
    public var provider: String
    public var scheduleEnabled: Bool
    public var scheduleType: String
    public var backupKprofiles: Bool
    public var backupCloudProfiles: Bool
    public var backupSettings: Bool
    public var backupSpools: Bool
    public var backupArchives: Bool
    public var allowInsecureHttp: Bool
    public var enabled: Bool

    public init(
        repositoryUrl: String,
        accessToken: String? = nil,
        branch: String = "main",
        provider: String = "github",
        scheduleEnabled: Bool = false,
        scheduleType: String = "daily",
        backupKprofiles: Bool = true,
        backupCloudProfiles: Bool = true,
        backupSettings: Bool = false,
        backupSpools: Bool = false,
        backupArchives: Bool = false,
        allowInsecureHttp: Bool = false,
        enabled: Bool = true
    ) {
        self.repositoryUrl = repositoryUrl
        self.accessToken = accessToken
        self.branch = branch
        self.provider = provider
        self.scheduleEnabled = scheduleEnabled
        self.scheduleType = scheduleType
        self.backupKprofiles = backupKprofiles
        self.backupCloudProfiles = backupCloudProfiles
        self.backupSettings = backupSettings
        self.backupSpools = backupSpools
        self.backupArchives = backupArchives
        self.allowInsecureHttp = allowInsecureHttp
        self.enabled = enabled
    }
}

/// Mise à jour partielle d'une configuration de sauvegarde Git (`PATCH /github-backup/config`).
/// Seuls les champs non-nil sont encodés (`exclude_unset` côté serveur) : laisser `accessToken` à
/// `nil` conserve le jeton existant. Le serveur ne re-valide le dépôt privé que si l'URL, le jeton
/// ou le fournisseur changent.
public struct GitHubBackupConfigUpdate: Encodable, Sendable, Hashable {
    public var repositoryUrl: String?
    public var accessToken: String?
    public var branch: String?
    public var provider: String?
    public var scheduleEnabled: Bool?
    public var scheduleType: String?
    public var backupKprofiles: Bool?
    public var backupCloudProfiles: Bool?
    public var backupSettings: Bool?
    public var backupSpools: Bool?
    public var backupArchives: Bool?
    public var allowInsecureHttp: Bool?
    public var enabled: Bool?

    public init(
        repositoryUrl: String? = nil,
        accessToken: String? = nil,
        branch: String? = nil,
        provider: String? = nil,
        scheduleEnabled: Bool? = nil,
        scheduleType: String? = nil,
        backupKprofiles: Bool? = nil,
        backupCloudProfiles: Bool? = nil,
        backupSettings: Bool? = nil,
        backupSpools: Bool? = nil,
        backupArchives: Bool? = nil,
        allowInsecureHttp: Bool? = nil,
        enabled: Bool? = nil
    ) {
        self.repositoryUrl = repositoryUrl
        self.accessToken = accessToken
        self.branch = branch
        self.provider = provider
        self.scheduleEnabled = scheduleEnabled
        self.scheduleType = scheduleType
        self.backupKprofiles = backupKprofiles
        self.backupCloudProfiles = backupCloudProfiles
        self.backupSettings = backupSettings
        self.backupSpools = backupSpools
        self.backupArchives = backupArchives
        self.allowInsecureHttp = allowInsecureHttp
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey {
        case repositoryUrl, accessToken, branch, provider, scheduleEnabled, scheduleType
        case backupKprofiles, backupCloudProfiles, backupSettings, backupSpools, backupArchives
        case allowInsecureHttp, enabled
    }

    /// Encode uniquement les champs renseignés (`exclude_unset` côté serveur) : un `nil` n'émet
    /// aucune clé, ce qui préserve la valeur existante côté serveur (jeton inclus).
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(repositoryUrl, forKey: .repositoryUrl)
        try container.encodeIfPresent(accessToken, forKey: .accessToken)
        try container.encodeIfPresent(branch, forKey: .branch)
        try container.encodeIfPresent(provider, forKey: .provider)
        try container.encodeIfPresent(scheduleEnabled, forKey: .scheduleEnabled)
        try container.encodeIfPresent(scheduleType, forKey: .scheduleType)
        try container.encodeIfPresent(backupKprofiles, forKey: .backupKprofiles)
        try container.encodeIfPresent(backupCloudProfiles, forKey: .backupCloudProfiles)
        try container.encodeIfPresent(backupSettings, forKey: .backupSettings)
        try container.encodeIfPresent(backupSpools, forKey: .backupSpools)
        try container.encodeIfPresent(backupArchives, forKey: .backupArchives)
        try container.encodeIfPresent(allowInsecureHttp, forKey: .allowInsecureHttp)
        try container.encodeIfPresent(enabled, forKey: .enabled)
    }
}

/// Réponse d'un déclenchement manuel de sauvegarde (`POST /github-backup/run`).
public struct GitHubBackupTriggerResult: Codable, Sendable, Hashable {
    public var success: Bool
    public var message: String?
    public var logId: Int?
    public var commitSha: String?
    public var filesChanged: Int?

    public init(
        success: Bool,
        message: String? = nil,
        logId: Int? = nil,
        commitSha: String? = nil,
        filesChanged: Int? = nil
    ) {
        self.success = success
        self.message = message
        self.logId = logId
        self.commitSha = commitSha
        self.filesChanged = filesChanged
    }
}
