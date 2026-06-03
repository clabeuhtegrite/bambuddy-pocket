// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Notification en-app dérivée d'un événement WebSocket (fin/début d'impression, alerte…).
struct AppNotification: Identifiable, Hashable {
    let id = UUID()
    let kind: NotableEventKind
    let printerName: String?
    let date: Date
}
