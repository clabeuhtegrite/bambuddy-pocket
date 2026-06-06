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

    /// Met à jour une imprimante côté serveur (`PATCH /printers/{id}`). Seuls les champs non `nil`
    /// de `PrinterUpdate` sont transmis (mise à jour partielle).
    func updatePrinter(id: Int, _ update: PrinterUpdate) async throws -> Printer {
        let body = try JSONEncoder.bambuddy().encode(update)
        return try await send("/printers/\(id)", method: .patch, body: body)
    }

    /// File d'attente d'impression (`GET /queue/`).
    func queue() async throws -> [QueueItem] {
        try await get("/queue/")
    }

    /// Flux d'activité du serveur (`GET /notifications/logs`). **Décodage tolérant par élément**
    /// (B0) : une entrée de log malformée est ignorée plutôt que de faire échouer tout le feed.
    func activityLog() async throws -> [ActivityEntry] {
        let lossy: LossyArray<ActivityEntry> = try await get("/notifications/logs")
        return lossy.elements
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

    /// Fichiers de la bibliothèque de modèles à la **racine** (`GET /library/files/`). Sans filtre,
    /// l'API ne renvoie que les fichiers sans dossier (`folder_id IS NULL`).
    func libraryFiles() async throws -> [LibraryFile] {
        try await get("/library/files/")
    }

    /// Fichiers contenus dans un **dossier** donné (`GET /library/files/?folder_id={id}`). Le
    /// listing racine n'inclut pas les fichiers des dossiers : il faut interroger chaque dossier.
    func libraryFiles(inFolder folderID: Int) async throws -> [LibraryFile] {
        try await get("/library/files/?folder_id=\(folderID)")
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

    /// Arbre des dossiers de la bibliothèque (`GET /library/folders/`).
    func libraryFolders() async throws -> [FolderTreeItem] {
        try await get("/library/folders/")
    }

    /// Déplace des fichiers vers un dossier — `folderID` nil = racine (`POST /library/files/move`).
    @discardableResult
    func moveLibraryFiles(_ request: FileMoveRequest) async throws -> FileMoveResult {
        let body = try JSONEncoder.bambuddy().encode(request)
        return try await send("/library/files/move", method: .post, body: body)
    }

    /// Contenu de la corbeille de la bibliothèque (`GET /library/trash`).
    func libraryTrash() async throws -> TrashListResponse {
        try await get("/library/trash")
    }

    /// Restaure un fichier depuis la corbeille (`POST /library/trash/{id}/restore`).
    func restoreTrashedFile(id: Int) async throws {
        try await post("/library/trash/\(id)/restore")
    }

    /// Supprime définitivement un fichier de la corbeille (`DELETE /library/trash/{id}`).
    func deleteTrashedFile(id: Int) async throws {
        try await delete("/library/trash/\(id)")
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

    /// Nomenclature (BOM) d'un projet (`GET /projects/{id}/bom`).
    func projectBOM(id: Int) async throws -> [BOMItem] {
        try await get("/projects/\(id)/bom")
    }

    /// Ajoute un élément à la nomenclature (`POST /projects/{id}/bom`).
    @discardableResult
    func addProjectBOMItem(projectID: Int, _ item: BOMItemCreate) async throws -> BOMItem {
        let body = try JSONEncoder.bambuddy().encode(item)
        return try await send("/projects/\(projectID)/bom", method: .post, body: body)
    }

    /// Supprime un élément de la nomenclature (`DELETE /projects/{id}/bom/{item_id}`).
    func deleteProjectBOMItem(projectID: Int, itemID: Int) async throws {
        try await delete("/projects/\(projectID)/bom/\(itemID)")
    }

    /// Chronologie d'un projet (`GET /projects/{id}/timeline`).
    func projectTimeline(id: Int) async throws -> [TimelineEvent] {
        try await get("/projects/\(id)/timeline")
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

    /// Déclenche l'envoi d'un code OTP par email (`POST /auth/2fa/email/send`). Le serveur consomme
    /// l'ancien `pre_auth_token` et en renvoie un **frais** à utiliser pour la vérification.
    func sendEmailOTP(preAuthToken: String) async throws -> EmailOTPSendResponse {
        let body = try JSONEncoder.bambuddy().encode(EmailOTPSendRequest(preAuthToken: preAuthToken))
        return try await send("/auth/2fa/email/send", method: .post, body: body)
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

    /// Frappe un jeton court d'accès au WebSocket temps réel (`POST /auth/ws-token`).
    ///
    /// Le handshake WebSocket ne transporte pas l'en-tête `Authorization` ; le serveur (auth activée)
    /// attend donc ce jeton opaque en `?token=` sur l'URL `…/ws`. JWT ou clé d'API l'obtiennent
    /// (permission `WEBSOCKET_CONNECT`). Inoffensif si l'auth est désactivée.
    func webSocketToken() async throws -> WebSocketToken {
        try await send("/auth/ws-token", method: .post, body: nil)
    }

    /// État de l'authentification à deux facteurs de l'utilisateur (`GET /auth/2fa/status`).
    func twoFactorStatus() async throws -> TwoFactorStatus {
        try await get("/auth/2fa/status")
    }

    /// Déconnexion : révoque le jeton courant côté serveur (`POST /auth/logout`).
    func logout() async throws {
        try await post("/auth/logout")
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

    /// Annule un travail de distribution automatique en arrière-plan
    /// (`DELETE /background-dispatch/{job_id}`). Les travaux en attente sont annulés
    /// immédiatement ; un travail actif est marqué pour annulation coopérative.
    func cancelDispatchJob(jobID: Int) async throws {
        try await delete("/background-dispatch/\(jobID)")
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

    /// Active/désactive une option d'impression / détection IA
    /// (`POST /printers/{id}/print-options?module_name=…&enabled=…&print_halt=…&sensitivity=…`).
    func setPrintOption(
        id: Int,
        moduleName: String,
        enabled: Bool,
        printHalt: Bool = true,
        sensitivity: String = "medium"
    ) async throws {
        let path = "/printers/\(id)/print-options?module_name=\(moduleName)"
            + "&enabled=\(enabled)&print_halt=\(printHalt)&sensitivity=\(sensitivity)"
        try await post(path)
    }

    /// Règle le mode du conduit d'air (`POST /printers/{id}/airduct-mode?mode=cooling|heating`).
    func setAirductMode(id: Int, mode: String) async throws {
        try await post("/printers/\(id)/airduct-mode?mode=\(mode)")
    }

    /// Ajuste l'écart buse-plateau d'une distance relative signée en mm
    /// (`POST /printers/{id}/bed-jog?distance=<mm>&force=<bool>`). Négatif = réduit l'écart.
    func bedJog(id: Int, distance: Double, force: Bool = false) async throws {
        let path = "/printers/\(id)/bed-jog?distance=\(distance)&force=\(force)"
        try await post(path)
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

    // MARK: Profils d'avance de pression (K)

    /// Profils K stockés sur l'imprimante (`GET /printers/{id}/kprofiles/`). Lecture seule :
    /// l'app ne pousse aucun profil sur l'imprimante.
    func kProfiles(printerID: Int) async throws -> KProfilesResponse {
        try await get("/printers/\(printerID)/kprofiles/")
    }

    /// Notes utilisateur des profils K (`GET /printers/{id}/kprofiles/notes`).
    func kProfileNotes(printerID: Int) async throws -> KProfileNotes {
        try await get("/printers/\(printerID)/kprofiles/notes")
    }
}
