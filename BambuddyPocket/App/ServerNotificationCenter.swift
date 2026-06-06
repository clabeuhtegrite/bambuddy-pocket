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
    /// Sondage REST **rapide** dédié à l'imprimante actuellement à l'écran (détail/accueil) : tant
    /// qu'un écran imprimante est visible, on rafraîchit son statut à cadence serrée pour refléter
    /// l'état quasi en temps réel quand le WebSocket ne passe pas Cloudflare.
    private var activePollTask: Task<Void, Never>?
    /// Imprimantes actuellement visibles à l'écran (compteur de références : plusieurs écrans
    /// peuvent observer la même imprimante). Le sondage rapide tourne tant que cet ensemble n'est
    /// pas vide.
    private var activePrinterRefcounts: [Int: Int] = [:]
    /// Noms d'imprimante connus, pour enrichir les notifications.
    private var printerNames: [Int: String] = [:]
    /// Statuts précédents, pour ne notifier les erreurs HMS qu'à la transition.
    private var previousStatuses: [Int: PrinterStatus] = [:]
    /// Dernière notification émise pour un code HMS alarmant donné (`"<printerID>:<code>"` → date),
    /// pour appliquer une **grâce** anti-flapping : un code qui réapparaît dans la fenêtre ne
    /// ré-alarme pas (la X2D fait clignoter certains codes ; cf. `_HMS_CLEAR_GRACE_SECONDS` amont).
    private var lastHMSNotified: [String: Date] = [:]
    /// Jeton WebSocket mis en cache (`POST /auth/ws-token`) + date de frappe. Réutilisé entre
    /// reconnexions pour **éviter un aller-retour réseau à chaque repli** : le jeton dure ~60 min,
    /// on ne le refrappe que s'il manque, qu'il a dépassé sa durée de vie utile, ou après une
    /// connexion qui a vécu (où le serveur a pu le faire tourner).
    private var cachedWebSocketToken: (value: String, fetchedAt: Date)?
    /// Un statut frais a-t-il déjà été obtenu via le repli REST ? Sert au **retour device A2** : une
    /// fois vrai, le badge ne retombe plus en « Connexion… » pendant que le WebSocket retente.
    private var hasFreshRESTStatus = false
    /// Horodatage du dernier `GET /printers/{id}/status` **réussi** par imprimante. Sert à
    /// **coalescer** les sondages qui se superposent sur l'imprimante active : le repli global (10 s),
    /// le sondage rapide (2,5 s) et le re-fetch post-action visent la même imprimante. Un fetch dont
    /// l'âge est inférieur à `minStatusFetchInterval` est sauté (sauf `force`), évitant les requêtes
    /// redondantes.
    private var lastStatusFetched: [Int: Date] = [:]
    /// Liste des imprimantes mise en cache (la composition du parc change rarement). Le repli REST ne
    /// re-télécharge plus `printers()` à chaque tick : il réutilise ce cache et ne (re)charge la liste
    /// que lorsqu'elle est vide. Un rafraîchissement explicite passe par `load()` du view-model.
    private var cachedPrinters: [Printer]?

    private static let maxNotifications = 100
    /// Cadence du repli REST quand le temps réel (WebSocket) est indisponible.
    private static let restPollInterval = Duration.seconds(10)
    /// Cadence **rapide** du sondage de l'imprimante active (écran imprimante visible). Plus serrée
    /// que le repli global car ciblée sur une seule imprimante : l'écran reflète l'état quasi en
    /// temps réel quand le WebSocket ne passe pas Cloudflare (cf. web UI). Aligné sur ~2–3 s.
    private static let activePollInterval = Duration.milliseconds(2500)
    /// Intervalle minimal entre deux `GET /printers/{id}/status` pour une **même** imprimante.
    /// Sous ce délai, un sondage non forcé est sauté : il dédoublonne les requêtes que le repli
    /// global, le sondage rapide et le re-fetch post-action lanceraient sinon en double. Calé un peu
    /// sous la cadence rapide (2,5 s) pour ne jamais retarder un tick rapide légitime.
    private static let minStatusFetchInterval: TimeInterval = 2
    /// Nombre d'échecs d'ouverture WebSocket **sans aucun événement reçu** avant de basculer en
    /// repli REST permanent (le handshake est rejeté, ex. Cloudflare Access refuse l'upgrade).
    private static let maxHandshakeFailuresBeforeRESTMode = 2
    /// Intervalle entre deux nouvelles tentatives WebSocket une fois en repli REST (au cas où le
    /// proxy/serveur se mette à accepter l'upgrade).
    private static let restModeProbeInterval = Duration.seconds(120)
    /// Fenêtre de grâce anti-flapping pour les erreurs HMS (aligné sur `_HMS_CLEAR_GRACE_SECONDS`
    /// amont) : un code alarmant déjà notifié il y a moins de ce délai ne ré-alarme pas.
    private static let hmsClearGrace: TimeInterval = 30
    /// Durée de vie utile d'un jeton WebSocket en cache. Le serveur émet des jetons ~60 min ; on
    /// reste prudemment en deçà pour qu'une reconnexion tardive ne tombe pas sur un jeton expiré.
    private static let webSocketTokenTTL: TimeInterval = 45 * 60
    /// Délai du **premier** essai de reconnexion après une coupure d'une connexion établie : court,
    /// pour reconnecter vite sur un simple « blip » (ex. expiration d'inactivité côté proxy).
    private static let firstReconnectDelay = Duration.milliseconds(250)
    /// Tolérance avant d'afficher « Reconnexion… » : une connexion qui retombe puis revient dans
    /// cette fenêtre ne fait pas clignoter le badge (le badge reste « connecté »). Ce n'est qu'au-
    /// delà — vraie coupure — que l'on passe en `.reconnecting`.
    private static let reconnectBadgeGrace = Duration.seconds(2)

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
        activePollTask?.cancel()
        activePollTask = nil
        activePrinterRefcounts.removeAll()
        hasFreshRESTStatus = false
        lastStatusFetched.removeAll()
        cancelBadgeReconnectTask()
    }

    /// Fournit les noms d'imprimante connus (depuis la liste REST) pour enrichir les notifications.
    func updatePrinterNames(from printers: [Printer]) {
        for printer in printers {
            printerNames[printer.id] = printer.name
        }
    }

    /// Synchronise le **cache de liste** depuis un chargement explicite (`load()` du view-model :
    /// pull-to-refresh, ajout/suppression d'imprimante). Le repli REST réutilise ce cache au lieu de
    /// re-télécharger `printers()` à chaque tick.
    func updatePrinterList(_ printers: [Printer]) {
        cachedPrinters = printers
        updatePrinterNames(from: printers)
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
        // Le dernier passage a-t-il établi une connexion vivante puis l'a perdue ? Sert à donner sa
        // chance à un reconnect rapide **avant** d'afficher « Reconnexion… » (tolérance au blip).
        var droppedFromLive = false
        while !Task.isCancelled {
            var receivedEvent = false
            do {
                // Auth activée : le handshake WebSocket ne porte pas l'en-tête `Authorization`, donc
                // on passe un jeton court (`POST /auth/ws-token`) ajouté en `?token=`. Sans lui le
                // serveur refuse l'upgrade (`close 4401`). Le jeton est **mis en cache** et réutilisé
                // entre reconnexions : on n'inflige pas un aller-retour réseau à chaque blip.
                let token = await webSocketToken(forceRefresh: droppedFromLive)
                let socket = try connectionFactory.makeWebSocketClient(for: server, token: token)
                for try await event in socket.events() {
                    if Task.isCancelled { break }
                    // Le tout premier événement confirme que l'upgrade est passé : c'est seulement
                    // ici qu'on peut affirmer que la connexion est réellement établie (le simple
                    // fait de construire le client n'ouvre pas la socket).
                    if !receivedEvent {
                        receivedEvent = true
                        handshakeFailures = 0
                        cancelBadgeReconnectTask()
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
                // La connexion a vécu puis est tombée. On **ne bascule pas immédiatement** le badge :
                // on tente d'abord un reconnect rapide en restant « connecté ». Ce n'est que si la
                // reconnexion tarde au-delà de la fenêtre de grâce que l'on affichera « Reconnexion ».
                droppedFromLive = true
                cancelBadgeReconnectTask()
                badgeReconnectTask = Task { [weak self] in
                    try? await Task.sleep(for: Self.reconnectBadgeGrace)
                    guard !Task.isCancelled else { return }
                    self?.markReconnectingIfStillDown()
                }
                try? await Task.sleep(for: Self.firstReconnectDelay)
                backoff = .seconds(1)
            } else {
                droppedFromLive = false
                // Échec d'ouverture sans aucun événement : probablement un upgrade refusé.
                handshakeFailures += 1
                if handshakeFailures >= Self.maxHandshakeFailuresBeforeRESTMode {
                    // Temps réel exclu : on passe en repli REST (badge honnête) et on retentera le
                    // WebSocket beaucoup plus tard, au cas où la configuration change.
                    cancelBadgeReconnectTask()
                    realtimeState = .restMode
                    try? await Task.sleep(for: Self.restModeProbeInterval)
                } else {
                    // On ne **rétrograde pas** le badge en « Connexion… » si le repli REST a déjà
                    // fourni un statut frais (retour device A2) : on reste « En direct » (restMode)
                    // pendant que le WebSocket retente en arrière-plan.
                    if !hasFreshRESTStatus {
                        realtimeState = .connecting
                    }
                    try? await Task.sleep(for: backoff)
                    backoff = min(backoff * 2, .seconds(30))
                }
            }
        }
        cancelBadgeReconnectTask()
    }

    /// Tâche différée qui affiche « Reconnexion… » si la reconnexion ne s'est pas rétablie dans la
    /// fenêtre de grâce. Annulée dès qu'une reconnexion réussit (passage à `.connected`).
    private var badgeReconnectTask: Task<Void, Never>?

    private func cancelBadgeReconnectTask() {
        badgeReconnectTask?.cancel()
        badgeReconnectTask = nil
    }

    /// Passe en `.reconnecting` seulement si l'on n'est pas déjà revenu en ligne entre-temps
    /// (la boucle remet `realtimeState = .connected` dès le premier événement reçu).
    private func markReconnectingIfStillDown() {
        if realtimeState != .connected, realtimeState != .restMode {
            realtimeState = .reconnecting
        }
    }

    /// Jeton WebSocket, **mis en cache**. Refrappé seulement s'il manque, qu'il a dépassé sa durée de
    /// vie utile, ou qu'on `forceRefresh` (reconnexion après une connexion qui a vécu : le serveur a
    /// pu faire tourner le jeton). Sur instance sans auth, renvoie `nil` sans aucun appel réseau.
    private func webSocketToken(forceRefresh: Bool) async -> String? {
        guard server.authMethod != .none else { return nil }
        if !forceRefresh, let reusable = reusableCachedToken() {
            return reusable
        }
        let fresh = await connectionFactory.webSocketToken(for: server)
        if let fresh {
            cachedWebSocketToken = (fresh, Date())
        }
        return fresh
    }

    /// Jeton en cache encore dans sa durée de vie utile, ou `nil` s'il manque ou est périmé.
    private func reusableCachedToken() -> String? {
        guard let cached = cachedWebSocketToken else { return nil }
        let age = Date().timeIntervalSince(cached.fetchedAt)
        return age < Self.webSocketTokenTTL ? cached.value : nil
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
    ///
    /// **Retour device A2** : dès qu'un **premier statut frais** est obtenu par REST alors qu'on est
    /// encore en `.connecting` (ouverture initiale du WebSocket pas encore aboutie), on promeut le
    /// badge en `.restMode` (« En direct » / sain) **sans attendre** l'aboutissement ou l'échec du
    /// handshake WebSocket (qui prenait ~15 s : tentatives + back-off). Le WebSocket continue en
    /// arrière-plan et peut toujours faire passer le badge en `.connected` (streaming).
    func refreshFromREST() async {
        guard let client = try? connectionFactory.makeClient(for: server) else { return }
        // La liste des imprimantes change rarement : on ne la re-télécharge pas à chaque tick de
        // 10 s. On réutilise le cache et on ne (re)charge `printers()` que s'il est vide ; un
        // rafraîchissement explicite (ajout/suppression) passe par `load()` du view-model.
        guard let printers = await cachedPrinterList(using: client) else { return }
        // On **ne re-poll pas** en global les imprimantes déjà couvertes par le sondage rapide
        // (écran imprimante visible) : elles sont déjà fraîches, ce serait un doublon.
        let active = Set(activePrinterRefcounts.keys)
        let targets = printers.filter { !active.contains($0.id) }
        // Sondages en **parallèle** (au lieu de séquentiel) : la latence totale n'est plus la somme
        // des appels mais celle du plus lent.
        let results = await withTaskGroup(of: (Int, PrinterStatus?).self) { group in
            for printer in targets {
                group.addTask { await (printer.id, try? client.printerStatus(id: printer.id)) }
            }
            var collected: [(Int, PrinterStatus)] = []
            for await (id, status) in group {
                if let status { collected.append((id, status)) }
            }
            return collected
        }
        for (id, status) in results {
            merge(status, into: id)
            lastStatusFetched[id] = Date()
        }
        if !results.isEmpty {
            promoteToRESTModeIfStillConnecting()
        }
    }

    /// Liste des imprimantes mise en cache (composition du parc rarement changeante). Recharge
    /// `printers()` uniquement si le cache est vide. Met à jour les noms connus au passage.
    private func cachedPrinterList(using client: RESTClient) async -> [Printer]? {
        if let cachedPrinters { return cachedPrinters }
        guard let printers = try? await client.printers() else { return nil }
        cachedPrinters = printers
        updatePrinterNames(from: printers)
        return printers
    }

    /// Promeut le badge `.connecting` → `.restMode` dès qu'un statut frais est disponible (REST).
    /// N'altère ni `.connected` (streaming WebSocket établi) ni `.reconnecting` (qui a sa propre
    /// fenêtre de grâce), ni un `.restMode` déjà acquis : on quitte seulement l'attente initiale.
    private func promoteToRESTModeIfStillConnecting() {
        hasFreshRESTStatus = true
        if realtimeState == .connecting {
            realtimeState = .restMode
        }
    }

    /// Re-fetch **ciblé** du statut d'une seule imprimante (`GET /printers/{id}/status`) puis fusion
    /// dans l'état partagé. Appelé juste après une action de contrôle pour resynchroniser
    /// immédiatement tous les écrans (détail **et** accueil). Silencieux en cas d'échec réseau/auth.
    /// Issue d'un re-fetch ciblé de statut, pour permettre à l'appelant de **sauter** une nouvelle
    /// tentative immédiate quand l'échec relève du transport (réseau injoignable).
    enum StatusFetchOutcome {
        /// Statut frais fusionné (ou requête sautée par coalescing — l'état partagé reste à jour).
        case refreshed
        /// Échec **transport** (réseau injoignable / délai dépassé) : un re-fetch immédiat est vain.
        case transportFailure
        /// Échec non transport (HTTP/auth/décodage) ou client indisponible.
        case otherFailure
    }

    @discardableResult
    func refreshStatus(for printerID: Int) async -> PrinterStatus? {
        await refreshStatus(for: printerID, force: false).status
    }

    /// Re-fetch ciblé avec contrôle du **coalescing** (`force` outrepasse l'intervalle minimal) et
    /// remontée de l'issue (transport/autre) pour l'appelant. Un fetch trop récent et non forcé est
    /// sauté : l'état partagé est déjà à jour, on évite une requête redondante.
    @discardableResult
    func refreshStatus(
        for printerID: Int,
        force: Bool
    ) async -> (status: PrinterStatus?, outcome: StatusFetchOutcome) {
        if !force, isStatusFresh(for: printerID) {
            return (statuses[printerID], .refreshed)
        }
        guard let client = try? connectionFactory.makeClient(for: server) else {
            return (statuses[printerID], .otherFailure)
        }
        do {
            let status = try await client.printerStatus(id: printerID)
            merge(status, into: printerID)
            lastStatusFetched[printerID] = Date()
            return (statuses[printerID], .refreshed)
        } catch let error as APIError where error.isTransport {
            return (statuses[printerID], .transportFailure)
        } catch {
            return (statuses[printerID], .otherFailure)
        }
    }

    /// Le statut de cette imprimante a-t-il été rafraîchi assez récemment pour sauter un nouveau
    /// fetch non forcé ? (`true` si l'âge du dernier fetch réussi est sous l'intervalle minimal.)
    private func isStatusFresh(for printerID: Int) -> Bool {
        guard let last = lastStatusFetched[printerID] else { return false }
        return Date().timeIntervalSince(last) < Self.minStatusFetchInterval
    }

    /// Fusionne un statut déjà décodé (ex. update optimiste local) dans l'état partagé. Exposé pour
    /// permettre une mise à jour optimiste d'un champ juste après l'envoi d'une commande, avant que
    /// le re-fetch ne confirme.
    func applyOptimistic(_ delta: PrinterStatus, into printerID: Int) {
        merge(delta, into: printerID)
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

// MARK: - Imprimante active (sondage rapide)

extension ServerNotificationCenter {
    /// Signale qu'un écran observe maintenant cette imprimante (détail/accueil visible). Démarre le
    /// sondage rapide si ce n'était pas déjà le cas. À équilibrer par `endObserving`.
    func beginObserving(printerID: Int) {
        activePrinterRefcounts[printerID, default: 0] += 1
        startActivePollIfNeeded()
    }

    /// Signale qu'un écran ne regarde plus cette imprimante. Arrête le sondage rapide quand plus
    /// aucun écran imprimante n'est visible.
    func endObserving(printerID: Int) {
        guard let count = activePrinterRefcounts[printerID] else { return }
        if count <= 1 {
            activePrinterRefcounts[printerID] = nil
        } else {
            activePrinterRefcounts[printerID] = count - 1
        }
        if activePrinterRefcounts.isEmpty {
            activePollTask?.cancel()
            activePollTask = nil
        }
    }

    private func startActivePollIfNeeded() {
        guard activePollTask == nil else { return }
        activePollTask = Task { [weak self] in
            await self?.activePollLoop()
        }
    }

    /// Sondage rapide des imprimantes visibles. Tourne **en complément** du WebSocket (et non
    /// seulement en repli) : il garantit que le toggle bouge vite après une action, même si le WS
    /// passe Cloudflare mais avec de la latence. Cadence serrée mais ciblée (une à quelques
    /// imprimantes), donc peu coûteuse.
    private func activePollLoop() async {
        while !Task.isCancelled {
            let ids = Array(activePrinterRefcounts.keys)
            for id in ids where !Task.isCancelled {
                await refreshStatus(for: id)
            }
            try? await Task.sleep(for: Self.activePollInterval)
        }
    }
}
