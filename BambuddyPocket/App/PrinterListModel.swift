// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model d'un serveur : liste des imprimantes (REST) + état temps réel partagé via le centre
/// de notifications persistant du serveur.
/// `@MainActor` : toutes les mutations d'état se font sur le thread principal.
@MainActor
@Observable
final class PrinterListModel {
    private(set) var printers: [Printer] = []
    private(set) var hasLoaded = false
    var loadError: String?
    var controlError: String?

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

    // MARK: Contrôles d'impression

    func pause(_ printer: Printer) async {
        await runControl { try await $0.pausePrint(id: printer.id) }
    }

    func resume(_ printer: Printer) async {
        await runControl { try await $0.resumePrint(id: printer.id) }
    }

    func stop(_ printer: Printer) async {
        await runControl { try await $0.stopPrint(id: printer.id) }
    }

    func clearErrors(_ printer: Printer) async {
        await runControl { try await $0.clearHMS(id: printer.id) }
    }

    func setChamberLight(_ printer: Printer, on: Bool) async {
        await runControl { try await $0.setChamberLight(id: printer.id, on: on) }
    }

    func setSpeed(_ printer: Printer, mode: Int) async {
        await runControl { try await $0.setPrintSpeed(id: printer.id, mode: mode) }
    }

    /// Active/désactive une option d'impression / détection IA.
    func setPrintOption(_ printer: Printer, moduleName: String, enabled: Bool) async {
        await runControl { try await $0.setPrintOption(id: printer.id, moduleName: moduleName, enabled: enabled) }
    }

    /// Règle le mode du conduit d'air (`cooling`/`heating`).
    func setAirductMode(_ printer: Printer, mode: String) async {
        await runControl { try await $0.setAirductMode(id: printer.id, mode: mode) }
    }

    /// Ajuste l'écart buse-plateau d'une distance relative (mm).
    func bedJog(_ printer: Printer, distance: Double, force: Bool = false) async {
        await runControl { try await $0.bedJog(id: printer.id, distance: distance, force: force) }
    }

    func unloadFilament(_ printer: Printer) async {
        await runControl { try await $0.amsUnload(id: printer.id) }
    }

    func loadFilament(_ printer: Printer, trayID: Int) async {
        await runControl { try await $0.amsLoad(id: printer.id, trayID: trayID) }
    }

    func clearPlate(_ printer: Printer) async {
        await runControl { try await $0.clearPlate(id: printer.id) }
    }

    func homeAxes(_ printer: Printer) async {
        await runControl { try await $0.homeAxes(id: printer.id) }
    }

    func connect(_ printer: Printer) async {
        await runControl { try await $0.connectPrinter(id: printer.id) }
    }

    func disconnect(_ printer: Printer) async {
        await runControl { try await $0.disconnectPrinter(id: printer.id) }
    }

    func calibrate(_ printer: Printer, options: CalibrationOptions) async {
        await runControl { try await $0.calibrate(id: printer.id, options: options) }
    }

    func skipObjects(_ printer: Printer, objectIDs: [Int]) async {
        await runControl { try await $0.skipObjects(id: printer.id, objectIDs: objectIDs) }
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
        await runControl { try await $0.startDrying(id: printer.id, amsID: amsID) }
    }

    func stopDrying(_ printer: Printer, amsID: Int) async {
        await runControl { try await $0.stopDrying(id: printer.id, amsID: amsID) }
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

    private func runControl(_ action: (RESTClient) async throws -> Void) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await action(client)
            controlError = nil
        } catch {
            controlError = Self.message(for: error)
        }
    }

    private static func message(for error: Error) -> String {
        switch error {
        case let apiError as APIError:
            message(for: apiError)
        default:
            error.localizedDescription
        }
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .invalidURL:
            String(localized: "The server URL is not valid.")
        case .unauthorized:
            String(localized: "Unauthorized — check your credentials.")
        case let .transport(message):
            message
        case let .http(status, _):
            String(localized: "The server returned an unexpected status (\(status)).")
        case .decoding:
            String(localized: "The server response could not be read.")
        case let .server(message):
            message
        }
    }
}
