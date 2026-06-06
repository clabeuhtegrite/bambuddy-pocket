// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation

/// Traitement des **événements** et dérivation des **notifications** : fusion des deltas de statut
/// (`merge`), application des événements WebSocket (`apply`/`ingest`), garde anti-flapping HMS
/// (`shouldNotifyHMS`) et enregistrement dans le feed (`record`). Extrait de
/// `ServerNotificationCenter` (limite 500 l. / corps de type 250 l.) ; cf.
/// `BambuddyEndpoints+Archives.swift` pour le même motif d'extraction.
extension ServerNotificationCenter {
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

    func apply(_ event: WebSocketEvent) {
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

    func merge(_ delta: PrinterStatus, into id: Int) {
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
