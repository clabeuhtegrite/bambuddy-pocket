// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Endpoints REST typés de l'API Bambuddy, exposés comme commodités sur tout `APIClient`.
/// Chemins relatifs au préfixe `/api/v1` (cf. `RequestFactory`).
public extension APIClient {
    /// Liste des imprimantes configurées sur le serveur (`GET /printers/`).
    func printers() async throws -> [Printer] {
        try await get("/printers/")
    }

    /// État temps réel complet d'une imprimante (`GET /printers/{id}/status`).
    func printerStatus(id: Int) async throws -> PrinterStatus {
        try await get("/printers/\(id)/status")
    }

    /// Ajoute une imprimante côté serveur (`POST /printers/`).
    func createPrinter(_ printer: PrinterCreate) async throws -> Printer {
        let body = try JSONEncoder.bambuddy().encode(printer)
        return try await send("/printers/", method: .post, body: body)
    }

    /// Archive d'impressions (`GET /archives/`), la plus récente d'abord côté serveur.
    func archives() async throws -> [Archive] {
        try await get("/archives/")
    }

    /// Détail d'une archive (`GET /archives/{id}`).
    func archive(id: Int) async throws -> Archive {
        try await get("/archives/\(id)")
    }

    /// Statistiques globales d'impression (`GET /archives/stats`).
    func archiveStats() async throws -> ArchiveStats {
        try await get("/archives/stats")
    }

    /// Recherche plein-texte côté serveur (`GET /archives/search?q=…`). Le serveur exige au
    /// moins deux caractères ; renvoie une liste vide pour une requête plus courte.
    func searchArchives(_ query: String) async throws -> [Archive] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return try await get("/archives/search?q=\(encoded)")
    }

    /// Édite les métadonnées d'une archive (`PATCH /archives/{id}`) et renvoie l'archive à jour.
    func updateArchive(id: Int, _ update: ArchiveUpdate) async throws -> Archive {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/archives/\(id)", method: .patch, body: body)
    }

    /// Bascule le statut « favori » d'une archive (`POST /archives/{id}/favorite`).
    func toggleArchiveFavorite(id: Int) async throws -> Archive {
        try await send("/archives/\(id)/favorite", method: .post, body: nil)
    }

    /// Supprime une archive (`DELETE /archives/{id}`).
    func deleteArchive(id: Int) async throws {
        try await delete("/archives/\(id)")
    }

    /// File d'attente d'impression (`GET /queue/`).
    func queue() async throws -> [QueueItem] {
        try await get("/queue/")
    }

    /// Flux d'activité du serveur (`GET /notifications/logs`).
    func activityLog() async throws -> [ActivityEntry] {
        try await get("/notifications/logs")
    }

    /// Inventaire des bobines de filament (`GET /inventory/spools`).
    func inventorySpools() async throws -> [Spool] {
        try await get("/inventory/spools")
    }

    /// Détail d'une bobine (`GET /inventory/spools/{id}`).
    func spool(id: Int) async throws -> Spool {
        try await get("/inventory/spools/\(id)")
    }

    /// Édite une bobine (`PATCH /inventory/spools/{id}`) et renvoie la bobine à jour.
    func updateSpool(id: Int, _ update: SpoolUpdate) async throws -> Spool {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/inventory/spools/\(id)", method: .patch, body: body)
    }

    /// Historique de consommation d'une bobine (`GET /inventory/spools/{id}/usage`).
    func spoolUsage(id: Int) async throws -> [SpoolUsage] {
        try await get("/inventory/spools/\(id)/usage")
    }

    /// Remet à zéro le compteur de consommation affiché (`POST /inventory/spools/{id}/reset-usage`).
    func resetSpoolUsage(id: Int) async throws -> Spool {
        try await send("/inventory/spools/\(id)/reset-usage", method: .post, body: nil)
    }

    /// Archive une bobine (`POST /inventory/spools/{id}/archive`).
    func archiveSpool(id: Int) async throws -> Spool {
        try await send("/inventory/spools/\(id)/archive", method: .post, body: nil)
    }

    /// Supprime une bobine (`DELETE /inventory/spools/{id}`).
    func deleteSpool(id: Int) async throws {
        try await delete("/inventory/spools/\(id)")
    }

    /// Fichiers de la bibliothèque de modèles (`GET /library/files/`).
    func libraryFiles() async throws -> [LibraryFile] {
        try await get("/library/files/")
    }

    /// Détail d'un fichier de bibliothèque (`GET /library/files/{id}`).
    func libraryFile(id: Int) async throws -> LibraryFile {
        try await get("/library/files/\(id)")
    }

    /// Édite un fichier de bibliothèque (`PUT /library/files/{id}`) et renvoie le fichier à jour.
    func updateLibraryFile(id: Int, _ update: LibraryFileUpdate) async throws -> LibraryFile {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/library/files/\(id)", method: .put, body: body)
    }

    /// Supprime un fichier de bibliothèque — déplacé vers la corbeille (`DELETE /library/files/{id}`).
    func deleteLibraryFile(id: Int) async throws {
        try await delete("/library/files/\(id)")
    }

    /// Projets d'impression (`GET /projects/`).
    func projects() async throws -> [Project] {
        try await get("/projects/")
    }

    /// Détail d'un projet (`GET /projects/{id}`).
    func project(id: Int) async throws -> Project {
        try await get("/projects/\(id)")
    }

    /// Crée un projet (`POST /projects/`) et renvoie le projet créé.
    func createProject(_ project: ProjectCreate) async throws -> Project {
        let body = try JSONEncoder.bambuddy().encode(project)
        return try await send("/projects/", method: .post, body: body)
    }

    /// Édite un projet (`PATCH /projects/{id}`) et renvoie le projet à jour.
    func updateProject(id: Int, _ update: ProjectUpdate) async throws -> Project {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/projects/\(id)", method: .patch, body: body)
    }

    /// Supprime un projet (`DELETE /projects/{id}`).
    func deleteProject(id: Int) async throws {
        try await delete("/projects/\(id)")
    }

    /// Réordonne la file d'attente (`POST /queue/reorder`).
    func reorderQueue(_ items: [QueueReorderItem]) async throws {
        let body = try JSONEncoder.bambuddy().encode(QueueReorder(items: items))
        try await post("/queue/reorder", body: body)
    }

    /// Ajoute un élément à la file (`POST /queue/`).
    func addToQueue(_ item: QueueItemCreate) async throws {
        let body = try JSONEncoder.bambuddy().encode(item)
        try await post("/queue/", body: body)
    }

    // MARK: Authentification (cf. docs/bambuddy-api.md §3)

    /// Connexion par identifiants (`POST /auth/login`).
    func login(username: String, password: String) async throws -> LoginResponse {
        let body = try JSONEncoder.bambuddy().encode(LoginRequest(username: username, password: password))
        return try await send("/auth/login", method: .post, body: body)
    }

    /// Vérification du second facteur (`POST /auth/2fa/verify`).
    func verifyTwoFactor(preAuthToken: String, code: String, method: String?) async throws -> TwoFAVerifyResponse {
        let request = TwoFAVerifyRequest(preAuthToken: preAuthToken, code: code, method: method)
        let body = try JSONEncoder.bambuddy().encode(request)
        return try await send("/auth/2fa/verify", method: .post, body: body)
    }

    /// Utilisateur courant — valide le token (`GET /auth/me`).
    func currentUser() async throws -> User {
        try await get("/auth/me")
    }

    /// Requête `POST` sans réponse utile (actions de contrôle).
    func post(_ path: String, body: Data? = nil) async throws {
        let _: EmptyResponse = try await send(path, method: .post, body: body)
    }

    /// Requête `DELETE` sans réponse utile.
    func delete(_ path: String) async throws {
        let _: EmptyResponse = try await send(path, method: .delete, body: nil)
    }

    // MARK: Actions sur la file

    /// Démarre un élément de la file (`POST /queue/{id}/start`).
    func startQueueItem(id: Int) async throws {
        try await post("/queue/\(id)/start")
    }

    /// Annule un élément de la file (`POST /queue/{id}/cancel`).
    func cancelQueueItem(id: Int) async throws {
        try await post("/queue/\(id)/cancel")
    }

    /// Arrête un élément en cours d'impression (`POST /queue/{id}/stop`).
    func stopQueueItem(id: Int) async throws {
        try await post("/queue/\(id)/stop")
    }

    /// Supprime un élément de la file (`DELETE /queue/{id}`).
    func deleteQueueItem(id: Int) async throws {
        try await delete("/queue/\(id)")
    }

    /// Édite un élément en attente (`PATCH /queue/{id}`) et renvoie l'élément mis à jour.
    func updateQueueItem(id: Int, _ update: QueueItemUpdate) async throws -> QueueItem {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/queue/\(id)", method: .patch, body: body)
    }

    /// Met à jour plusieurs éléments en attente d'un coup (`PATCH /queue/bulk`).
    @discardableResult
    func bulkUpdateQueue(_ update: QueueBulkUpdate) async throws -> QueueBulkUpdateResponse {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/queue/bulk", method: .patch, body: body)
    }

    /// Liste les lots d'impression (`GET /queue/batches`).
    func queueBatches() async throws -> [PrintBatch] {
        try await get("/queue/batches")
    }

    /// Annule un lot et tous ses éléments en attente (`DELETE /queue/batches/{id}`).
    func cancelQueueBatch(id: Int) async throws {
        try await delete("/queue/batches/\(id)")
    }

    // MARK: Caméra

    /// État du flux caméra (`GET /printers/{id}/camera/status`).
    func cameraStatus(printerID: Int) async throws -> CameraStatus {
        try await get("/printers/\(printerID)/camera/status")
    }

    /// Détecte si le plateau est vide par vision (`GET /printers/{id}/camera/check-plate`).
    func checkPlate(printerID: Int) async throws -> PlateCheck {
        try await get("/printers/\(printerID)/camera/check-plate")
    }

    /// Crée un jeton de flux caméra réutilisable (`POST /printers/camera/stream-token`).
    func cameraStreamToken() async throws -> CameraStreamToken {
        try await send("/printers/camera/stream-token", method: .post, body: nil)
    }

    // MARK: Contrôles d'impression (cf. docs/bambuddy-api.md §7)

    /// Met l'impression en pause (`POST /printers/{id}/print/pause`).
    func pausePrint(id: Int) async throws {
        try await post("/printers/\(id)/print/pause")
    }

    /// Reprend l'impression (`POST /printers/{id}/print/resume`).
    func resumePrint(id: Int) async throws {
        try await post("/printers/\(id)/print/resume")
    }

    /// Arrête l'impression (`POST /printers/{id}/print/stop`).
    func stopPrint(id: Int) async throws {
        try await post("/printers/\(id)/print/stop")
    }

    /// Efface les erreurs HMS (`POST /printers/{id}/hms/clear`).
    func clearHMS(id: Int) async throws {
        try await post("/printers/\(id)/hms/clear")
    }

    /// Allume/éteint la lumière de chambre (`POST /printers/{id}/chamber-light?on=<bool>`).
    func setChamberLight(id: Int, on: Bool) async throws {
        try await post("/printers/\(id)/chamber-light?on=\(on)")
    }

    /// Règle la vitesse d'impression (`POST /printers/{id}/print-speed?mode=<1…4>`).
    func setPrintSpeed(id: Int, mode: Int) async throws {
        try await post("/printers/\(id)/print-speed?mode=\(mode)")
    }

    /// Décharge le filament courant (`POST /printers/{id}/ams/unload`).
    func amsUnload(id: Int) async throws {
        try await post("/printers/\(id)/ams/unload")
    }

    /// Démarre le séchage d'une unité AMS (`POST /printers/{id}/drying/start?ams_id=<int>`).
    func startDrying(id: Int, amsID: Int) async throws {
        try await post("/printers/\(id)/drying/start?ams_id=\(amsID)")
    }

    /// Arrête le séchage d'une unité AMS (`POST /printers/{id}/drying/stop?ams_id=<int>`).
    func stopDrying(id: Int, amsID: Int) async throws {
        try await post("/printers/\(id)/drying/stop?ams_id=\(amsID)")
    }

    /// Charge le filament d'un plateau AMS (`POST /printers/{id}/ams/load?tray_id=<int>`).
    func amsLoad(id: Int, trayID: Int) async throws {
        try await post("/printers/\(id)/ams/load?tray_id=\(trayID)")
    }

    /// Réinitialise un plateau AMS (`POST /printers/{id}/ams/{ams}/tray/{tray}/reset`).
    func amsResetTray(id: Int, amsID: Int, trayID: Int) async throws {
        try await post("/printers/\(id)/ams/\(amsID)/tray/\(trayID)/reset")
    }

    // MARK: Contrôles avancés (cf. docs/bambuddy-api.md §7)

    /// Confirme le retrait de la plaque (`POST /printers/{id}/clear-plate`).
    func clearPlate(id: Int) async throws {
        try await post("/printers/\(id)/clear-plate")
    }

    /// Lance un cycle de calage automatique des axes (`POST /printers/{id}/home-axes`).
    func homeAxes(id: Int) async throws {
        try await post("/printers/\(id)/home-axes")
    }

    /// Connecte l'imprimante au serveur (`POST /printers/{id}/connect`).
    func connectPrinter(id: Int) async throws {
        try await post("/printers/\(id)/connect")
    }

    /// Déconnecte l'imprimante du serveur (`POST /printers/{id}/disconnect`).
    func disconnectPrinter(id: Int) async throws {
        try await post("/printers/\(id)/disconnect")
    }

    /// Lance une calibration ciblée (`POST /printers/{id}/calibration?<flags>`).
    func calibrate(id: Int, options: CalibrationOptions) async throws {
        try await post("/printers/\(id)/calibration?\(options.queryString)")
    }

    /// Objets imprimables de la plaque courante (`GET /printers/{id}/print/objects`).
    func printObjects(id: Int) async throws -> PrintObjects {
        try await get("/printers/\(id)/print/objects")
    }

    /// Demande à ignorer les objets indiqués (`POST /printers/{id}/print/skip-objects`).
    func skipObjects(id: Int, objectIDs: [Int]) async throws {
        let body = try JSONEncoder.bambuddy().encode(objectIDs)
        try await post("/printers/\(id)/print/skip-objects", body: body)
    }

    /// Supprime une imprimante côté serveur (`DELETE /printers/{id}`).
    func deletePrinter(id: Int) async throws {
        try await delete("/printers/\(id)")
    }
}
