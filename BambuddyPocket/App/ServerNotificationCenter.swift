// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// État de la connexion temps réel (WebSocket) d'un serveur.
enum RealtimeState: Equatable {
    /// Première tentative d'ouverture du WebSocket (aucun événement encore reçu).
    case connecting
    /// WebSocket établi : les deltas vivants arrivent en temps réel.
    case connected
    /// WebSocket tombé après avoir été établi : tentative de reconnexion en cours.
    case reconnecting
    /// WebSocket indisponible (ex. upgrade refusé par un proxy Cloudflare) : l'app fonctionne en
    /// **repli REST** (rafraîchissement périodique). Les données restent vivantes, mais sans
    /// streaming. Évite d'afficher « Reconnexion… » indéfiniment quand le temps réel est exclu.
    case restMode
}

/// Service de notifications **au niveau serveur** : maintient une session WebSocket persistante
/// (vivante tant que le serveur est sélectionné, indépendamment de l'écran affiché), fusionne les
/// deltas de statut et dérive des notifications en-app (bannières + feed) sur les événements
/// notables (`print_start`/`print_complete`, bobine manquante, plateau non vide, HMS grave,
/// archive créée).
///
/// `@MainActor` : toutes les mutations d'état se font sur le thread principal. L'instance est mise
/// en cache par `ServerListModel` et partagée entre tous les écrans d'un même serveur.
@MainActor
@Observable
final class ServerNotificationCenter {
    /// État temps réel fusionné, par identifiant d'imprimante (REST initial + deltas WebSocket).
    private(set) var statuses: [Int: PrinterStatus] = [:]
    private(set) var realtimeState: RealtimeState = .connecting
    /// Feed horodaté, du plus récent au plus ancien (borné à `maxNotifications`).
    private(set) var notifications: [AppNotification] = []
    /// Dernière notification reçue non encore acquittée par une bannière (consommée par l'UI).
    private(set) var latestBanner: AppNotification?
    /// État courant de la distribution automatique en arrière-plan (`nil` si inactive).
    private(set) var dispatchState: BackgroundDispatchState?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory
    private var realtimeTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    /// Noms d'imprimante connus, pour enrichir les notifications.
    private var printerNames: [Int: String] = [:]
    /// Statuts précédents, pour ne notifier les erreurs HMS qu'à la transition.
    private var previousStatuses: [Int: PrinterStatus] = [:]
    /// Dernière notification émise pour un code HMS alarmant donné (`"<printerID>:<code>"` → date),
    /// pour appliquer une **grâce** anti-flapping : un code qui réapparaît dans la fenêtre ne
    /// ré-alarme pas (la X2D fait clignoter certains codes ; cf. `_HMS_CLEAR_GRACE_SECONDS` amont).
    private var lastHMSNotified: [String: Date] = [:]

    private static let maxNotifications = 100
    /// Cadence du repli REST quand le temps réel (WebSocket) est indisponible.
    private static let restPollInterval = Duration.seconds(10)
    /// Nombre d'échecs d'ouverture WebSocket **sans aucun événement reçu** avant de basculer en
    /// repli REST permanent (le handshake est rejeté, ex. Cloudflare Access refuse l'upgrade).
    private static let maxHandshakeFailuresBeforeRESTMode = 2
    /// Intervalle entre deux nouvelles tentatives WebSocket une fois en repli REST (au cas où le
    /// proxy/serveur se mette à accepter l'upgrade).
    private static let restModeProbeInterval = Duration.seconds(120)
    /// Fenêtre de grâce anti-flapping pour les erreurs HMS (aligné sur `_HMS_CLEAR_GRACE_SECONDS`
    /// amont) : un code alarmant déjà notifié il y a moins de ce délai ne ré-alarme pas.
    private static let hmsClearGrace: TimeInterval = 30

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    /// Nombre de notifications non lues (badge).
    var unreadCount: Int {
        notifications.lazy.count(where: { !$0.isRead })
    }

    /// État temps réel fusionné pour une imprimante donnée.
    func status(for printerID: Int) -> PrinterStatus? {
        statuses[printerID]
    }

    /// Démarre la session temps réel persistante (idempotent : un seul flux par centre).
    ///
    /// Un **repli REST** tourne en parallèle : il amorce immédiatement les statuts via
    /// `GET /printers/{id}/status` et continue de les rafraîchir tant que le WebSocket n'est pas
    /// `connected`. Cela garantit l'affichage des données vivantes (températures, AMS, impression)
    /// même quand le temps réel est indisponible (ex. WebSocket bloqué par un proxy Cloudflare).
    func start() {
        guard realtimeTask == nil else { return }
        realtimeTask = Task { [weak self] in
            await self?.realtimeLoop()
        }
        pollTask = Task { [weak self] in
            await self?.restPollLoop()
        }
    }

    /// Arrête la session temps réel (à appeler quand le serveur n'est plus sélectionné).
    func stop() {
        realtimeTask?.cancel()
        realtimeTask = nil
        pollTask?.cancel()
        pollTask = nil
    }

    /// Fournit les noms d'imprimante connus (depuis la liste REST) pour enrichir les notifications.
    func updatePrinterNames(from printers: [Printer]) {
        for printer in printers {
            printerNames[printer.id] = printer.name
        }
    }

    /// Marque tout le feed comme lu (à l'ouverture du centre de notifications).
    func markAllAsRead() {
        for index in notifications.indices where !notifications[index].isRead {
            notifications[index].isRead = true
        }
    }

    /// Acquitte la bannière courante (après son affichage).
    func dismissBanner() {
        latestBanner = nil
    }

    /// Vide entièrement le feed.
    func clear() {
        notifications.removeAll()
        latestBanner = nil
    }

    // MARK: Temps réel

    private func realtimeLoop() async {
        var backoff = Duration.seconds(1)
        // Nombre d'échecs consécutifs d'ouverture sans avoir reçu le moindre événement : permet de
        // distinguer un WebSocket qui tombe en cours de route (à reconnecter) d'un upgrade
        // systématiquement refusé (Cloudflare) → repli REST.
        var handshakeFailures = 0
        while !Task.isCancelled {
            var receivedEvent = false
            do {
                // Auth activée : le handshake WebSocket ne porte pas l'en-tête `Authorization`, donc
                // on frappe d'abord un jeton court (`POST /auth/ws-token`) ajouté en `?token=`. Sans
                // lui le serveur refuse l'upgrade (`close 4401`). Le jeton est refrappé à chaque
                // (re)connexion : il dure ~60 min mais une reconnexion tardive doit rester valide.
                let token = await connectionFactory.webSocketToken(for: server)
                let socket = try connectionFactory.makeWebSocketClient(for: server, token: token)
                for try await event in socket.events() {
                    if Task.isCancelled { break }
                    // Le tout premier événement confirme que l'upgrade est passé : c'est seulement
                    // ici qu'on peut affirmer que la connexion est réellement établie (le simple
                    // fait de construire le client n'ouvre pas la socket).
                    if !receivedEvent {
                        receivedEvent = true
                        handshakeFailures = 0
                        realtimeState = .connected
                    }
                    apply(event)
                    backoff = .seconds(1)
                }
            } catch {
                // Connexion tombée / upgrade refusé : on décide ci-dessous entre reconnexion et repli.
            }
            if Task.isCancelled { break }

            if receivedEvent {
                // La connexion a vécu puis est tombée : on tente une vraie reconnexion (back-off).
                realtimeState = .reconnecting
                try? await Task.sleep(for: backoff)
                backoff = min(backoff * 2, .seconds(30))
            } else {
                // Échec d'ouverture sans aucun événement : probablement un upgrade refusé.
                handshakeFailures += 1
                if handshakeFailures >= Self.maxHandshakeFailuresBeforeRESTMode {
                    // Temps réel exclu : on passe en repli REST (badge honnête) et on retentera le
                    // WebSocket beaucoup plus tard, au cas où la configuration change.
                    realtimeState = .restMode
                    try? await Task.sleep(for: Self.restModeProbeInterval)
                } else {
                    realtimeState = .connecting
                    try? await Task.sleep(for: backoff)
                    backoff = min(backoff * 2, .seconds(30))
                }
            }
        }
    }

    /// Repli REST : amorce les statuts puis les rafraîchit périodiquement **tant que** le temps réel
    /// n'est pas établi (états `connecting`, `reconnecting`, `restMode`). Dès que le WebSocket est
    /// `connected`, il pousse les deltas vivants et ce repli se met en sommeil (il reprend si la
    /// connexion retombe).
    private func restPollLoop() async {
        while !Task.isCancelled {
            if realtimeState != .connected {
                await refreshFromREST()
            }
            try? await Task.sleep(for: Self.restPollInterval)
        }
    }

    /// Récupère l'état complet de chaque imprimante via REST (`GET /printers/{id}/status`) et le
    /// fusionne dans l'état partagé. Sans effet (silencieux) en cas d'échec réseau/auth.
    func refreshFromREST() async {
        guard let client = try? connectionFactory.makeClient(for: server) else { return }
        guard let printers = try? await client.printers() else { return }
        updatePrinterNames(from: printers)
        for printer in printers {
            if let status = try? await client.printerStatus(id: printer.id) {
                merge(status, into: printer.id)
            }
        }
    }

    /// Injecte un événement comme s'il provenait du WebSocket (utilisé par les tests).
    func ingest(_ event: WebSocketEvent) {
        apply(event)
    }

    private func apply(_ event: WebSocketEvent) {
        switch event {
        case let .printerStatus(id, delta):
            merge(delta, into: id)
        case let .printStart(id, status), let .printComplete(id, status):
            record(event.notableEvent)
            if let status { merge(status, into: id) }
        case .missingSpoolAssignment, .plateNotEmpty, .archiveCreated:
            record(event.notableEvent)
        case let .backgroundDispatch(state):
            dispatchState = state.isActive ? state : nil
        case .pong, .other:
            break
        }
    }

    /// Annule un travail de distribution automatique en arrière-plan. L'état se met à jour via le
    /// WebSocket (diffusion du nouvel état) ; renvoie `false` en cas d'échec.
    func cancelDispatchJob(_ jobID: Int) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.cancelDispatchJob(jobID: jobID)
            return true
        } catch {
            return false
        }
    }

    private func merge(_ delta: PrinterStatus, into id: Int) {
        let current = statuses[id] ?? PrinterStatus()
        let merged = current.merged(with: delta)
        // Erreur HMS grave : ne notifier qu'à l'apparition (transition d'état) et hors fenêtre de
        // grâce anti-flapping (un code qui clignote ne ré-alarme pas).
        let hms = merged.severeHMSEvent(comparedTo: previousStatuses[id], printerID: id)
        if let hms, shouldNotifyHMS(hms, printerID: id) {
            record(hms)
        }
        previousStatuses[id] = merged
        statuses[id] = merged
    }

    /// Le HMS grave doit-il alarmer ? Non s'il a déjà été notifié dans la fenêtre de grâce (anti-
    /// flapping). Met à jour l'horodatage de dernière alarme quand la réponse est `true`.
    private func shouldNotifyHMS(_ hms: NotableEvent, printerID: Int) -> Bool {
        guard let detail = hms.detail else { return true }
        let key = "\(printerID):\(detail)"
        let now = Date()
        if let last = lastHMSNotified[key], now.timeIntervalSince(last) < Self.hmsClearGrace {
            return false
        }
        lastHMSNotified[key] = now
        return true
    }

    private func record(_ notable: NotableEvent?) {
        guard let notable else { return }
        let name = notable.printerID.flatMap { printerNames[$0] }
        let notification = AppNotification(
            kind: notable.kind,
            printerName: name,
            detail: notable.detail,
            date: Date()
        )
        notifications.insert(notification, at: 0)
        if notifications.count > Self.maxNotifications {
            notifications.removeLast(notifications.count - Self.maxNotifications)
        }
        latestBanner = notification
    }
}
