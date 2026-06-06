// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Endpoints REST de gestion serveur et d'intégrations (réglages, système, sauvegardes, clés
/// d'API, maintenance, firmware, prises connectées, liens externes, catalogue de filaments).
/// Séparés des endpoints d'impression pour garder chaque fichier sous la limite de longueur.
public extension APIClient {
    // MARK: Réglages (cf. docs/bambuddy-api.md §settings)

    /// Réglages serveur (`GET /settings/`).
    func settings() async throws -> AppSettings {
        try await get("/settings/")
    }

    /// Met à jour partiellement les réglages (`PATCH /settings/`) et renvoie l'état complet.
    @discardableResult
    func updateSettings(_ update: AppSettingsUpdate) async throws -> AppSettings {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/settings/", method: .patch, body: body)
    }

    // MARK: Sauvegardes locales (cf. docs/bambuddy-api.md §local-backup)

    /// État du système de sauvegarde locale (`GET /local-backup/status`).
    func backupStatus() async throws -> BackupStatus {
        try await get("/local-backup/status")
    }

    /// Liste des fichiers de sauvegarde (`GET /local-backup/backups`).
    func backups() async throws -> [BackupFile] {
        try await get("/local-backup/backups")
    }

    /// Déclenche une sauvegarde immédiate (`POST /local-backup/run`).
    @discardableResult
    func runBackup() async throws -> BackupRunResult {
        try await send("/local-backup/run", method: .post, body: nil)
    }

    // MARK: Liens externes (cf. docs/bambuddy-api.md §external-links)

    /// Liens externes personnalisés du serveur (`GET /external-links/`).
    func externalLinks() async throws -> [ExternalLink] {
        try await get("/external-links/")
    }

    /// Crée un lien externe (`POST /external-links/`).
    func createExternalLink(_ link: ExternalLinkCreate) async throws -> ExternalLink {
        let body = try JSONEncoder.bambuddy().encode(link)
        return try await send("/external-links/", method: .post, body: body)
    }

    /// Supprime un lien externe (`DELETE /external-links/{id}`).
    func deleteExternalLink(id: Int) async throws {
        try await delete("/external-links/\(id)")
    }

    // MARK: Catalogue de filaments (cf. docs/bambuddy-api.md §filament-catalog)

    /// Catalogue de filaments de référence (`GET /filament-catalog/`).
    func filamentCatalog() async throws -> [FilamentCatalogEntry] {
        try await get("/filament-catalog/")
    }

    // MARK: Firmware (cf. docs/bambuddy-api.md §firmware)

    /// Disponibilité des mises à jour firmware par imprimante (`GET /firmware/updates`).
    func firmwareUpdates() async throws -> FirmwareUpdates {
        try await get("/firmware/updates")
    }

    // MARK: Maintenance (cf. docs/bambuddy-api.md §maintenance)

    /// Vue d'ensemble de la maintenance par imprimante (`GET /maintenance/overview`).
    func maintenanceOverview() async throws -> [MaintenanceOverview] {
        try await get("/maintenance/overview")
    }

    /// Marque un élément de maintenance comme effectué (`POST /maintenance/items/{id}/perform`).
    @discardableResult
    func performMaintenance(itemID: Int, notes: String? = nil) async throws -> MaintenanceItem {
        let body = try JSONEncoder.bambuddy().encode(PerformMaintenance(notes: notes))
        return try await send("/maintenance/items/\(itemID)/perform", method: .post, body: body)
    }

    // MARK: Prises connectées (cf. docs/bambuddy-api.md §smart-plugs)

    /// Liste les prises connectées (`GET /smart-plugs/`).
    func smartPlugs() async throws -> [SmartPlug] {
        try await get("/smart-plugs/")
    }

    /// État temps réel d'une prise (`GET /smart-plugs/{id}/status`).
    func smartPlugStatus(id: Int) async throws -> SmartPlugStatus {
        try await get("/smart-plugs/\(id)/status")
    }

    /// Pilote l'alimentation d'une prise (`POST /smart-plugs/{id}/control`, action on/off/toggle).
    func controlSmartPlug(id: Int, action: SmartPlugAction) async throws {
        let body = try JSONEncoder.bambuddy().encode(SmartPlugControl(action: action))
        try await post("/smart-plugs/\(id)/control", body: body)
    }

    // MARK: Clés d'API (cf. docs/bambuddy-api.md §api-keys)

    /// Liste les clés d'API (`GET /api-keys/`). Le secret complet n'est pas renvoyé.
    func apiKeys() async throws -> [APIKey] {
        try await get("/api-keys/")
    }

    /// Crée une clé d'API (`POST /api-keys/`). La réponse contient le **secret complet** une fois.
    func createAPIKey(_ key: APIKeyCreate) async throws -> APIKey {
        let body = try JSONEncoder.bambuddy().encode(key)
        return try await send("/api-keys/", method: .post, body: body)
    }

    /// Met à jour une clé (`PATCH /api-keys/{id}`), p. ex. pour la révoquer (`enabled = false`).
    @discardableResult
    func updateAPIKey(id: Int, _ update: APIKeyUpdate) async throws -> APIKey {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/api-keys/\(id)", method: .patch, body: body)
    }

    /// Supprime une clé d'API (`DELETE /api-keys/{id}`).
    func deleteAPIKey(id: Int) async throws {
        try await delete("/api-keys/\(id)")
    }

    // MARK: Découverte réseau (cf. docs/bambuddy-api.md §discovery)

    /// État de la découverte réseau (`GET /discovery/status`).
    func discoveryStatus() async throws -> DiscoveryStatus {
        try await get("/discovery/status")
    }

    /// Informations sur l'environnement de découverte (`GET /discovery/info`).
    func discoveryInfo() async throws -> DiscoveryInfo {
        try await get("/discovery/info")
    }

    /// Imprimantes découvertes sur le réseau (`GET /discovery/printers`).
    func discoveredPrinters() async throws -> [DiscoveredPrinter] {
        try await get("/discovery/printers")
    }

    /// Démarre la découverte SSDP (`POST /discovery/start`).
    @discardableResult
    func startDiscovery() async throws -> DiscoveryStatus {
        try await send("/discovery/start", method: .post, body: nil)
    }

    /// Arrête la découverte SSDP (`POST /discovery/stop`).
    @discardableResult
    func stopDiscovery() async throws -> DiscoveryStatus {
        try await send("/discovery/stop", method: .post, body: nil)
    }

    // MARK: Journal d'impression (cf. docs/bambuddy-api.md §print-log)

    /// Journal d'impression paginé (`GET /print-log/`). `search` filtre par nom de travail
    /// (`ilike`), `limit`/`offset` paginent (au plus 500 par page côté serveur).
    func printLog(search: String? = nil, limit: Int = 50, offset: Int = 0) async throws -> PrintLogPage {
        var query = "limit=\(limit)&offset=\(offset)"
        let trimmed = search?.isEmpty == false ? search : nil
        if let encoded = trimmed?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            query += "&search=\(encoded)"
        }
        return try await get("/print-log/?\(query)")
    }

    /// Vide le journal d'impression (`DELETE /print-log/`). N'affecte ni les archives ni la file.
    func clearPrintLog() async throws {
        try await delete("/print-log/")
    }

    // MARK: Imprimantes virtuelles (cf. docs/bambuddy-api.md §virtual-printers)

    /// Liste les imprimantes virtuelles + table des modèles (`GET /virtual-printers`).
    func virtualPrinters() async throws -> VirtualPrinterList {
        try await get("/virtual-printers")
    }

    /// Détail d'une imprimante virtuelle (`GET /virtual-printers/{id}`).
    func virtualPrinter(id: Int) async throws -> VirtualPrinter {
        try await get("/virtual-printers/\(id)")
    }

    /// Crée une imprimante virtuelle (`POST /virtual-printers`).
    @discardableResult
    func createVirtualPrinter(_ create: VirtualPrinterCreate) async throws -> VirtualPrinter {
        let body = try JSONEncoder.bambuddy().encode(create)
        return try await send("/virtual-printers", method: .post, body: body)
    }

    /// Met à jour une imprimante virtuelle (`PUT /virtual-printers/{id}`).
    @discardableResult
    func updateVirtualPrinter(id: Int, _ update: VirtualPrinterUpdate) async throws -> VirtualPrinter {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/virtual-printers/\(id)", method: .put, body: body)
    }

    /// Supprime une imprimante virtuelle (`DELETE /virtual-printers/{id}`).
    func deleteVirtualPrinter(id: Int) async throws {
        try await delete("/virtual-printers/\(id)")
    }

    // MARK: Support / diagnostic (cf. docs/bambuddy-api.md §support)

    /// État du journal de débogage (`GET /support/debug-logging`).
    func debugLoggingState() async throws -> DebugLoggingState {
        try await get("/support/debug-logging")
    }

    /// Active ou désactive le journal de débogage (`POST /support/debug-logging`).
    @discardableResult
    func setDebugLogging(enabled: Bool) async throws -> DebugLoggingState {
        let body = try JSONEncoder.bambuddy().encode(["enabled": enabled])
        return try await send("/support/debug-logging", method: .post, body: body)
    }

    /// Journal applicatif récent du serveur (`GET /support/logs`), filtrable par niveau et texte.
    func serverLogs(limit: Int = 200, level: String? = nil, search: String? = nil) async throws -> LogsResponse {
        var query = "limit=\(limit)"
        if let level, !level.isEmpty {
            query += "&level=\(level)"
        }
        let trimmed = search?.isEmpty == false ? search : nil
        if let encoded = trimmed?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            query += "&search=\(encoded)"
        }
        return try await get("/support/logs?\(query)")
    }

    /// Vide le journal applicatif du serveur (`DELETE /support/logs`).
    func clearServerLogs() async throws {
        try await delete("/support/logs")
    }

    // MARK: Spoolman (cf. docs/bambuddy-api.md §spoolman)

    /// État de l'intégration Spoolman (`GET /spoolman/status`).
    func spoolmanStatus() async throws -> SpoolmanStatus {
        try await get("/spoolman/status")
    }

    /// Réglages Spoolman (`GET /settings/spoolman`). Booléens renvoyés en chaînes.
    func spoolmanSettings() async throws -> SpoolmanSettings {
        try await get("/settings/spoolman")
    }

    /// Met à jour les réglages Spoolman (`PUT /settings/spoolman`) et renvoie l'état complet.
    @discardableResult
    func updateSpoolmanSettings(_ update: SpoolmanSettingsUpdate) async throws -> SpoolmanSettings {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/settings/spoolman", method: .put, body: body)
    }

    /// Tente de se connecter au serveur Spoolman configuré (`POST /spoolman/connect`).
    func connectSpoolman() async throws {
        try await post("/spoolman/connect")
    }

    /// Se déconnecte du serveur Spoolman (`POST /spoolman/disconnect`).
    func disconnectSpoolman() async throws {
        try await post("/spoolman/disconnect")
    }

    // MARK: Sauvegarde distante Git (cf. docs/bambuddy-api.md §github-backup)

    /// État de la sauvegarde distante Git (`GET /github-backup/status`).
    func gitHubBackupStatus() async throws -> GitHubBackupStatus {
        try await get("/github-backup/status")
    }

    /// Configuration de la sauvegarde distante Git (`GET /github-backup/config`). `nil` si aucune
    /// configuration n'existe (le serveur renvoie alors le littéral JSON `null`).
    func gitHubBackupConfig() async throws -> GitHubBackupConfig? {
        try await get("/github-backup/config")
    }

    /// Crée ou met à jour la configuration de sauvegarde Git (`POST /github-backup/config`).
    /// Le serveur valide que le dépôt est **privé** avant d'accepter.
    @discardableResult
    func saveGitHubBackupConfig(_ config: GitHubBackupConfigCreate) async throws -> GitHubBackupConfig {
        let body = try JSONEncoder.bambuddy().encode(config)
        return try await send("/github-backup/config", method: .post, body: body)
    }

    /// Met à jour partiellement la configuration de sauvegarde Git (`PATCH /github-backup/config`).
    /// Seuls les champs renseignés sont transmis (le jeton existant est préservé si `accessToken` nil).
    @discardableResult
    func updateGitHubBackupConfig(_ update: GitHubBackupConfigUpdate) async throws -> GitHubBackupConfig {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/github-backup/config", method: .patch, body: body)
    }

    /// Supprime la configuration de sauvegarde Git (`DELETE /github-backup/config`).
    func deleteGitHubBackupConfig() async throws {
        try await delete("/github-backup/config")
    }

    /// Journal des sauvegardes Git (`GET /github-backup/logs`), le plus récent en premier.
    /// **Décodage tolérant par élément** (B0) : une entrée malformée est ignorée plutôt que de faire
    /// échouer tout le journal.
    func gitHubBackupLogs() async throws -> [GitHubBackupLog] {
        let lossy: LossyArray<GitHubBackupLog> = try await get("/github-backup/logs")
        return lossy.elements
    }

    /// Déclenche une sauvegarde manuelle immédiate (`POST /github-backup/run`).
    @discardableResult
    func runGitHubBackup() async throws -> GitHubBackupTriggerResult {
        try await send("/github-backup/run", method: .post, body: nil)
    }

    // MARK: Système (cf. docs/bambuddy-api.md §system)

    /// État du serveur (`GET /system/info`) : app, machine, mémoire, CPU, stockage, base.
    func systemInfo() async throws -> SystemInfo {
        try await get("/system/info")
    }

    /// Diagnostic de santé du serveur (`GET /system/health`) : analyse des journaux.
    func systemHealth() async throws -> SystemHealth {
        try await get("/system/health")
    }
}
