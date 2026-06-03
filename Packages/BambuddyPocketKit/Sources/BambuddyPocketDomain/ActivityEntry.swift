// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Une entrée du flux d'activité serveur (`GET /notifications/logs`).
///
/// Sous-ensemble de `NotificationLogResponse` : historique des notifications émises côté serveur
/// (fin d'impression, HMS, etc.), exploité en lecture comme journal d'activité.
public struct ActivityEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var eventType: String
    public var title: String
    public var message: String
    public var success: Bool
    public var printerName: String?
    public var createdAt: String?

    public init(
        id: Int,
        eventType: String,
        title: String,
        message: String,
        success: Bool,
        printerName: String? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.title = title
        self.message = message
        self.success = success
        self.printerName = printerName
        self.createdAt = createdAt
    }
}
