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
