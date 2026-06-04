// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État du serveur Bambuddy (`GET /system/info`). Sous-ensemble robuste : application, machine,
/// mémoire, CPU, stockage disque et statistiques de base de données. Champs optionnels — clés
/// inconnues ignorées au décodage.
public struct SystemInfo: Codable, Sendable, Hashable {
    public var app: AppInfo?
    public var system: HostInfo?
    public var memory: MemoryInfo?
    public var cpu: CPUInfo?
    public var storage: StorageInfo?
    public var database: DatabaseStats?

    public init(
        app: AppInfo? = nil,
        system: HostInfo? = nil,
        memory: MemoryInfo? = nil,
        cpu: CPUInfo? = nil,
        storage: StorageInfo? = nil,
        database: DatabaseStats? = nil
    ) {
        self.app = app
        self.system = system
        self.memory = memory
        self.cpu = cpu
        self.storage = storage
        self.database = database
    }
}

/// Informations sur l'application serveur.
public struct AppInfo: Codable, Sendable, Hashable {
    public var version: String?

    public init(version: String? = nil) {
        self.version = version
    }
}

/// Informations sur la machine hôte.
public struct HostInfo: Codable, Sendable, Hashable {
    public var platform: String?
    public var platformRelease: String?
    public var architecture: String?
    public var hostname: String?
    public var pythonVersion: String?
    public var uptimeFormatted: String?

    public init(
        platform: String? = nil,
        platformRelease: String? = nil,
        architecture: String? = nil,
        hostname: String? = nil,
        pythonVersion: String? = nil,
        uptimeFormatted: String? = nil
    ) {
        self.platform = platform
        self.platformRelease = platformRelease
        self.architecture = architecture
        self.hostname = hostname
        self.pythonVersion = pythonVersion
        self.uptimeFormatted = uptimeFormatted
    }
}

/// Utilisation mémoire.
public struct MemoryInfo: Codable, Sendable, Hashable {
    public var totalFormatted: String?
    public var usedFormatted: String?
    public var availableFormatted: String?
    public var percentUsed: Double?

    public init(
        totalFormatted: String? = nil,
        usedFormatted: String? = nil,
        availableFormatted: String? = nil,
        percentUsed: Double? = nil
    ) {
        self.totalFormatted = totalFormatted
        self.usedFormatted = usedFormatted
        self.availableFormatted = availableFormatted
        self.percentUsed = percentUsed
    }
}

/// Utilisation processeur.
public struct CPUInfo: Codable, Sendable, Hashable {
    public var count: Int?
    public var percent: Double?

    public init(count: Int? = nil, percent: Double? = nil) {
        self.count = count
        self.percent = percent
    }
}

/// Utilisation du disque.
public struct StorageInfo: Codable, Sendable, Hashable {
    public var diskTotalFormatted: String?
    public var diskUsedFormatted: String?
    public var diskFreeFormatted: String?
    public var diskPercentUsed: Double?
    public var archiveSizeFormatted: String?
    public var databaseSizeFormatted: String?

    public init(
        diskTotalFormatted: String? = nil,
        diskUsedFormatted: String? = nil,
        diskFreeFormatted: String? = nil,
        diskPercentUsed: Double? = nil,
        archiveSizeFormatted: String? = nil,
        databaseSizeFormatted: String? = nil
    ) {
        self.diskTotalFormatted = diskTotalFormatted
        self.diskUsedFormatted = diskUsedFormatted
        self.diskFreeFormatted = diskFreeFormatted
        self.diskPercentUsed = diskPercentUsed
        self.archiveSizeFormatted = archiveSizeFormatted
        self.databaseSizeFormatted = databaseSizeFormatted
    }
}

/// Statistiques de la base de données (compteurs d'objets).
public struct DatabaseStats: Codable, Sendable, Hashable {
    public var engine: String?
    public var archives: Int?
    public var printers: Int?
    public var filaments: Int?
    public var projects: Int?
    public var totalPrintTimeFormatted: String?
    public var totalFilamentKg: Double?

    public init(
        engine: String? = nil,
        archives: Int? = nil,
        printers: Int? = nil,
        filaments: Int? = nil,
        projects: Int? = nil,
        totalPrintTimeFormatted: String? = nil,
        totalFilamentKg: Double? = nil
    ) {
        self.engine = engine
        self.archives = archives
        self.printers = printers
        self.filaments = filaments
        self.projects = projects
        self.totalPrintTimeFormatted = totalPrintTimeFormatted
        self.totalFilamentKg = totalFilamentKg
    }
}

/// Résultat du diagnostic de santé (`GET /system/health`) : analyse des journaux serveur.
public struct SystemHealth: Codable, Sendable, Hashable {
    public var scannedEntries: Int?
    public var logAvailable: Bool?
    public var summary: HealthSummary?

    public init(
        scannedEntries: Int? = nil,
        logAvailable: Bool? = nil,
        summary: HealthSummary? = nil
    ) {
        self.scannedEntries = scannedEntries
        self.logAvailable = logAvailable
        self.summary = summary
    }

    /// Le serveur signale-t-il au moins un problème ?
    public var hasFindings: Bool {
        (summary?.total ?? 0) > 0
    }
}

/// Synthèse des problèmes détectés dans les journaux.
public struct HealthSummary: Codable, Sendable, Hashable {
    public var total: Int?
    public var bug: Int?
    public var environment: Int?
    public var layer8: Int?

    public init(total: Int? = nil, bug: Int? = nil, environment: Int? = nil, layer8: Int? = nil) {
        self.total = total
        self.bug = bug
        self.environment = environment
        self.layer8 = layer8
    }
}
