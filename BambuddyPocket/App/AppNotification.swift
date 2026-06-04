// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Notification en-app dérivée d'un événement WebSocket (fin/début d'impression, alerte…).
struct AppNotification: Identifiable, Hashable {
    let id = UUID()
    let kind: NotableEventKind
    /// Nom de l'imprimante concernée, si l'événement en porte une.
    let printerName: String?
    /// Détail facultatif (nom du travail, libellé d'archive, code HMS…).
    let detail: String?
    let date: Date
    /// `false` tant que l'utilisateur n'a pas ouvert le centre de notifications.
    var isRead: Bool = false
}
