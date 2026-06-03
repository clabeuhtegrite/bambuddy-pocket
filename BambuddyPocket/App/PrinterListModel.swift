// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// État de la connexion temps réel (WebSocket) d'un serveur.
enum RealtimeState: Equatable {
    case connecting
    case connected
    case reconnecting
}

/// View-model d'un serveur : liste des imprimantes (REST) + état temps réel (WebSocket) fusionné.
/// `@MainActor` : toutes les mutations d'état se font sur le thread principal.
@MainActor
@Observable
final class PrinterListModel {
    private(set) var printers: [Printer] = []
    private(set) var statuses: [Int: PrinterStatus] = [:]
    private(set) var realtimeState: RealtimeState = .connecting
    private(set) var hasLoaded = false
    private(set) var notifications: [AppNotification] = []
    var loadError: String?
    var controlError: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    var serverLabel: String {
        server.label
    }

    /// État temps réel fusionné pour une imprimante (REST initial + deltas WebSocket).
    func status(for printer: Printer) -> PrinterStatus? {
        statuses[printer.id]
    }

    /// Charge la liste des imprimantes via REST (appelable en pull-to-refresh).
    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            let fetched = try await client.printers()
            printers = fetched.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            loadError = nil
        } catch {
            loadError = Self.message(for: error)
        }
        hasLoaded = true
    }

    /// Point d'entrée du cycle de vie de l'écran : charge la liste puis entretient le flux temps
    /// réel jusqu'à annulation de la tâche (à brancher sur `.task`).
    func run() async {
        await load()
        await realtimeLoop()
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

    func startDrying(_ printer: Printer, amsID: Int) async {
        await runControl { try await $0.startDrying(id: printer.id, amsID: amsID) }
    }

    func stopDrying(_ printer: Printer, amsID: Int) async {
        await runControl { try await $0.stopDrying(id: printer.id, amsID: amsID) }
    }

    /// Client de flux caméra MJPEG pour cette imprimante (`nil` si l'URL/secret échoue).
    func cameraStream(for printer: Printer) -> CameraStreamClient? {
        try? connectionFactory.makeCameraStream(for: server, printerID: printer.id)
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

    /// Récupère un snapshot caméra (JPEG) ; `nil` en cas d'échec (caméra absente, auth…).
    func cameraSnapshot(for printer: Printer) async -> Data? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.cameraSnapshot(printerID: printer.id)
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

    private func realtimeLoop() async {
        var backoff = Duration.seconds(1)
        while !Task.isCancelled {
            do {
                let socket = try connectionFactory.makeWebSocketClient(for: server)
                realtimeState = .connected
                for try await event in socket.events() {
                    if Task.isCancelled {
                        break
                    }
                    apply(event)
                    backoff = .seconds(1)
                }
            } catch {
                // Connexion tombée : on tente une reconnexion ci-dessous.
            }
            if Task.isCancelled {
                break
            }
            realtimeState = .reconnecting
            try? await Task.sleep(for: backoff)
            backoff = min(backoff * 2, .seconds(30))
        }
    }

    private func apply(_ event: WebSocketEvent) {
        recordNotification(for: event)
        switch event {
        case let .printerStatus(id, delta):
            merge(delta, into: id)
        case let .printStart(id, status), let .printComplete(id, status):
            if let status {
                merge(status, into: id)
            }
        case .missingSpoolAssignment, .plateNotEmpty, .pong, .other:
            break
        }
    }

    private func recordNotification(for event: WebSocketEvent) {
        guard let notable = event.notableEvent else { return }
        let name = printers.first { $0.id == notable.printerID }?.name
        notifications.insert(
            AppNotification(kind: notable.kind, printerName: name, date: Date()),
            at: 0
        )
        if notifications.count > 50 {
            notifications.removeLast(notifications.count - 50)
        }
    }

    private func merge(_ delta: PrinterStatus, into id: Int) {
        let current = statuses[id] ?? PrinterStatus()
        statuses[id] = current.merged(with: delta)
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
