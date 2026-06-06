// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model d'un serveur : liste des imprimantes (REST) + état temps réel partagé via le centre
/// de notifications persistant du serveur.
/// `@MainActor` : toutes les mutations d'état se font sur le thread principal.
/// Action de contrôle identifiable, pour afficher un **état « en cours »** sur le contrôle précis
/// tapé (roue/désactivation) tant que la commande n'est pas confirmée par le re-fetch. Sur la X2D
/// réelle la commande MQTT met ~1 s à se refléter : sans cet état, l'utilisateur subit un long
/// silence entre le tap et la confirmation (retour device A1).
enum PrinterControlAction: Hashable {
    case pauseResume
    case stop
    case light
    case speed
    case printOption(String)
    case airduct
    case unloadFilament
    case loadFilament
    case clearPlate
    case homeAxes
    case connect
    case disconnect
    case calibrate
    case clearErrors
    case drying
}

@MainActor
@Observable
final class PrinterListModel {
    private(set) var printers: [Printer] = []
    private(set) var hasLoaded = false
    var loadError: String?
    var controlError: String?

    /// Actions de contrôle actuellement en vol, par identifiant d'imprimante. Une action y reste
    /// du tap jusqu'à la fin du re-fetch de confirmation (`runControl`). Les vues interrogent
    /// `isRunning(_:for:)` pour afficher une roue / désactiver le contrôle concerné.
    private(set) var inFlightActions: [Int: Set<PrinterControlAction>] = [:]

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory
    /// Session WebSocket persistante partagée (statuts fusionnés, notifications).
    let notificationCenter: ServerNotificationCenter

    init(
        server: ServerConfiguration,
        connectionFactory: ServerConnectionFactory,
        notificationCenter: ServerNotificationCenter
    ) {
        self.server = server
        self.connectionFactory = connectionFactory
        self.notificationCenter = notificationCenter
    }

    var serverLabel: String {
        server.label
    }

    /// État de la connexion temps réel (relayé depuis le centre de notifications partagé).
    var realtimeState: RealtimeState {
        notificationCenter.realtimeState
    }

    /// État temps réel fusionné pour une imprimante (REST initial + deltas WebSocket partagés).
    func status(for printer: Printer) -> PrinterStatus? {
        notificationCenter.status(for: printer.id)
    }

    /// Charge la liste des imprimantes via REST (appelable en pull-to-refresh).
    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let fetched = try await client.printers()
            printers = fetched.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            notificationCenter.updatePrinterNames(from: printers)
            loadError = nil
        } catch {
            loadError = Self.message(for: error)
        }
        hasLoaded = true
    }

    /// Point d'entrée du cycle de vie de l'écran : charge la liste (le flux temps réel est porté
    /// par le centre de notifications persistant, indépendant de cet écran).
    func run() async {
        await load()
    }

    /// Maintient le **sondage rapide** de l'imprimante active tant que l'écran qui l'appelle est
    /// affiché (à brancher sur `.task` : la tâche est annulée à la disparition de la vue). Le
    /// statut de l'imprimante est rafraîchi à cadence serrée (~2,5 s) pour refléter l'état quasi en
    /// temps réel quand le WebSocket ne passe pas Cloudflare.
    func observeActivePrinter(_ printer: Printer) async {
        await observeActivePrinters([printer.id])
    }

    /// Variante multi-imprimantes (accueil/liste) : maintient le sondage rapide pour tout un jeu
    /// d'imprimantes tant que l'écran est affiché.
    func observeActivePrinters(_ printerIDs: [Int]) async {
        for id in printerIDs {
            notificationCenter.beginObserving(printerID: id)
        }
        defer {
            for id in printerIDs {
                notificationCenter.endObserving(printerID: id)
            }
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3600))
        }
    }

    // MARK: Contrôles d'impression

    func pause(_ printer: Printer) async {
        await runControl(for: printer, action: .pauseResume) { try await $0.pausePrint(id: printer.id) }
    }

    func resume(_ printer: Printer) async {
        await runControl(for: printer, action: .pauseResume) { try await $0.resumePrint(id: printer.id) }
    }

    func stop(_ printer: Printer) async {
        await runControl(for: printer, action: .stop) { try await $0.stopPrint(id: printer.id) }
    }

    func clearErrors(_ printer: Printer) async {
        await runControl(for: printer, action: .clearErrors) { try await $0.clearHMS(id: printer.id) }
    }

    func setChamberLight(_ printer: Printer, on: Bool) async {
        // Update **optimiste** : le toggle bouge tout de suite (comme la web UI), avant même le
        // re-fetch — sur la X2D réelle la commande MQTT met ~1 s à se refléter. Le re-fetch de
        // `runControl` confirmera ensuite l'état réel.
        var optimistic = PrinterStatus()
        optimistic.chamberLight = on
        notificationCenter.applyOptimistic(optimistic, into: printer.id)
        await runControl(for: printer, action: .light) { try await $0.setChamberLight(id: printer.id, on: on) }
    }

    func setSpeed(_ printer: Printer, mode: Int) async {
        await runControl(for: printer, action: .speed) { try await $0.setPrintSpeed(id: printer.id, mode: mode) }
    }

    /// Active/désactive une option d'impression / détection IA.
    func setPrintOption(_ printer: Printer, moduleName: String, enabled: Bool) async {
        await runControl(for: printer, action: .printOption(moduleName)) {
            try await $0.setPrintOption(id: printer.id, moduleName: moduleName, enabled: enabled)
        }
    }

    /// Règle le mode du conduit d'air (`cooling`/`heating`).
    func setAirductMode(_ printer: Printer, mode: String) async {
        await runControl(for: printer, action: .airduct) { try await $0.setAirductMode(id: printer.id, mode: mode) }
    }

    /// Ajuste l'écart buse-plateau d'une distance relative (mm).
    func bedJog(_ printer: Printer, distance: Double, force: Bool = false) async {
        await runControl(for: printer) { try await $0.bedJog(id: printer.id, distance: distance, force: force) }
    }

    func unloadFilament(_ printer: Printer) async {
        await runControl(for: printer, action: .unloadFilament) { try await $0.amsUnload(id: printer.id) }
    }

    func loadFilament(_ printer: Printer, trayID: Int) async {
        await runControl(for: printer, action: .loadFilament) { try await $0.amsLoad(id: printer.id, trayID: trayID) }
    }

    func clearPlate(_ printer: Printer) async {
        await runControl(for: printer, action: .clearPlate) { try await $0.clearPlate(id: printer.id) }
    }

    func homeAxes(_ printer: Printer) async {
        await runControl(for: printer, action: .homeAxes) { try await $0.homeAxes(id: printer.id) }
    }

    func connect(_ printer: Printer) async {
        await runControl(for: printer, action: .connect) { try await $0.connectPrinter(id: printer.id) }
    }

    func disconnect(_ printer: Printer) async {
        await runControl(for: printer, action: .disconnect) { try await $0.disconnectPrinter(id: printer.id) }
    }

    func calibrate(_ printer: Printer, options: CalibrationOptions) async {
        await runControl(for: printer, action: .calibrate) { try await $0.calibrate(id: printer.id, options: options) }
    }

    func skipObjects(_ printer: Printer, objectIDs: [Int]) async {
        await runControl(for: printer) { try await $0.skipObjects(id: printer.id, objectIDs: objectIDs) }
    }

    /// Charge les objets imprimables de la plaque courante (`nil` en cas d'échec).
    func printObjects(for printer: Printer) async -> PrintObjects? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.printObjects(id: printer.id)
        } catch {
            controlError = Self.message(for: error)
            return nil
        }
    }

    /// Supprime une imprimante côté serveur puis recharge la liste. Renvoie `true` au succès.
    func deletePrinter(_ printer: Printer) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deletePrinter(id: printer.id)
            await load()
            return true
        } catch {
            controlError = Self.message(for: error)
            return false
        }
    }

    /// Ajoute une imprimante côté serveur puis recharge la liste. Renvoie `true` au succès.
    func addPrinter(_ create: PrinterCreate) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            _ = try await client.createPrinter(create)
            await load()
            return true
        } catch {
            controlError = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Met à jour une imprimante côté serveur (PATCH partiel) puis recharge la liste. Renvoie
    /// `true` au succès.
    func updatePrinter(id: Int, _ update: PrinterUpdate) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            _ = try await client.updatePrinter(id: id, update)
            await load()
            return true
        } catch {
            controlError = ErrorMessage.text(for: error)
            return false
        }
    }

    func startDrying(_ printer: Printer, amsID: Int) async {
        await runControl(for: printer, action: .drying) { try await $0.startDrying(id: printer.id, amsID: amsID) }
    }

    func stopDrying(_ printer: Printer, amsID: Int) async {
        await runControl(for: printer, action: .drying) { try await $0.stopDrying(id: printer.id, amsID: amsID) }
    }

    /// Demande un jeton de flux caméra réutilisable (`POST /printers/camera/stream-token`).
    /// Requis pour le flux/snapshot quand l'auth est activée ; inoffensif sinon. `nil` en cas
    /// d'échec (on retombe alors sur un accès sans jeton).
    func cameraStreamToken() async -> String? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.cameraStreamToken().token
        } catch {
            return nil
        }
    }

    /// Client de flux caméra MJPEG pour cette imprimante (`nil` si l'URL/secret échoue). Le jeton,
    /// quand il est fourni, autorise l'accès au flux sur un serveur protégé par auth.
    func cameraStream(for printer: Printer, token: String? = nil) -> CameraStreamClient? {
        try? connectionFactory.makeCameraStream(for: server, printerID: printer.id, token: token)
    }

    /// Détecte si le plateau est vide par vision (`nil` en cas d'échec). Met `controlError` à jour.
    func checkPlate(for printer: Printer) async -> PlateCheck? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.checkPlate(printerID: printer.id)
        } catch {
            controlError = Self.message(for: error)
            return nil
        }
    }

    /// Profils d'avance de pression (K) lus sur l'imprimante (lecture seule). `nil` en cas d'échec
    /// (imprimante hors ligne ou ne répondant pas à la requête de calibration).
    func kProfiles(for printer: Printer) async -> KProfilesResponse? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.kProfiles(printerID: printer.id)
        } catch {
            controlError = Self.message(for: error)
            return nil
        }
    }

    /// Récupère un snapshot caméra (JPEG) ; `nil` en cas d'échec (caméra absente, auth…). Le jeton,
    /// quand il est fourni, autorise l'accès au snapshot sur un serveur protégé par auth.
    func cameraSnapshot(for printer: Printer, token: String? = nil) async -> Data? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.cameraSnapshot(printerID: printer.id, token: token)
        } catch {
            return nil
        }
    }

    /// Exécute une action de contrôle puis **resynchronise le statut** de l'imprimante concernée :
    ///
    /// 1. envoie la commande (lumière, séchage, vitesse, AMS load/unload, clear-plate…) ;
    /// 2. **re-fetch** `GET /printers/{id}/status` et le **fusionne** dans
    ///    `ServerNotificationCenter` → tous les écrans (détail **et** accueil) reflètent le nouvel
    ///    état immédiatement, sans attendre le WebSocket (qui ne passe pas Cloudflare) ;
    /// 3. un **409** (conflit) est traité comme un **no-op réussi** : l'état désiré est déjà atteint
    ///    (« AMS already drying », lumière déjà dans l'état demandé). Pas d'erreur affichée — on
    ///    rafraîchit simplement le statut pour resynchroniser le toggle.
    ///
    /// C'est le cœur du correctif P1 : avant, la commande partait sans re-fetch, donc le toggle
    /// restait figé jusqu'à un redémarrage de l'app (et un re-clic renvoyait 409).
    private func runControl(
        for printer: Printer,
        action controlAction: PrinterControlAction? = nil,
        _ request: (RESTClient) async throws -> Void
    ) async {
        // Marque l'action « en vol » dès le tap → l'UI affiche une roue / désactive le contrôle
        // concerné, sans attendre la confirmation MQTT (~1 s sur la X2D réelle). L'entrée est
        // retirée après le re-fetch de confirmation (succès, 409 ou erreur).
        if let controlAction {
            inFlightActions[printer.id, default: []].insert(controlAction)
        }
        defer {
            if let controlAction {
                inFlightActions[printer.id]?.remove(controlAction)
                if inFlightActions[printer.id]?.isEmpty == true {
                    inFlightActions[printer.id] = nil
                }
            }
        }
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await request(client)
            controlError = nil
        } catch let error as APIError where error.isConflict {
            // 409 : l'état désiré est déjà atteint → succès du point de vue utilisateur.
            controlError = nil
        } catch {
            controlError = Self.message(for: error)
        }
        // Resynchronise le statut quel que soit le résultat (succès ou 409) : le re-fetch confirme
        // l'état réel et fait bouger le toggle sur tous les écrans.
        await notificationCenter.refreshStatus(for: printer.id)
    }

    private static func message(for error: Error) -> String {
        // Source unique de la traduction des erreurs (cf. `ErrorMessage`) : un seul mapping
        // 401/403/404 partagé par tous les view-models.
        ErrorMessage.text(for: error)
    }
}

// MARK: - État « action en vol » (retour device A1)

extension PrinterListModel {
    /// Une action donnée est-elle en cours pour cette imprimante ?
    func isRunning(_ action: PrinterControlAction, for printer: Printer) -> Bool {
        inFlightActions[printer.id]?.contains(action) ?? false
    }

    /// Une **quelconque** action est-elle en cours pour cette imprimante (carte d'accueil) ?
    func hasRunningAction(for printerID: Int) -> Bool {
        !(inFlightActions[printerID]?.isEmpty ?? true)
    }
}
