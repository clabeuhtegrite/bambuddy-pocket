// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État de l'intégration Spoolman (`GET /spoolman/status`) : gestion externe de l'inventaire de
/// bobines. `connected` reflète un contrôle de santé en direct du serveur Spoolman configuré.
public struct SpoolmanStatus: Codable, Sendable, Hashable {
    public var enabled: Bool
    public var connected: Bool
    public var url: String?

    public init(enabled: Bool = false, connected: Bool = false, url: String? = nil) {
        self.enabled = enabled
        self.connected = connected
        self.url = url
    }
}

/// Réglages de l'intégration Spoolman (`GET`/`PUT /settings/spoolman`).
///
/// Le serveur stocke et renvoie les booléens sous forme de **chaînes** (`"true"`/`"false"`) : ce
/// modèle conserve les chaînes brutes et expose des accesseurs typés. Le PUT renvoie les réglages
/// à jour dans le même format.
public struct SpoolmanSettings: Codable, Sendable, Hashable {
    public var spoolmanEnabled: String
    public var spoolmanUrl: String
    public var spoolmanSyncMode: String
    public var spoolmanDisableWeightSync: String
    public var spoolmanReportPartialUsage: String

    public init(
        spoolmanEnabled: String = "false",
        spoolmanUrl: String = "",
        spoolmanSyncMode: String = "auto",
        spoolmanDisableWeightSync: String = "false",
        spoolmanReportPartialUsage: String = "true"
    ) {
        self.spoolmanEnabled = spoolmanEnabled
        self.spoolmanUrl = spoolmanUrl
        self.spoolmanSyncMode = spoolmanSyncMode
        self.spoolmanDisableWeightSync = spoolmanDisableWeightSync
        self.spoolmanReportPartialUsage = spoolmanReportPartialUsage
    }

    /// L'intégration est-elle activée ?
    public var isEnabled: Bool {
        spoolmanEnabled.lowercased() == "true"
    }

    /// La synchronisation du poids est-elle désactivée ?
    public var isWeightSyncDisabled: Bool {
        spoolmanDisableWeightSync.lowercased() == "true"
    }

    /// L'usage partiel est-il signalé ?
    public var reportsPartialUsage: Bool {
        spoolmanReportPartialUsage.lowercased() == "true"
    }

    /// Convertit un booléen Swift en chaîne attendue par le serveur.
    public static func flag(_ value: Bool) -> String {
        value ? "true" : "false"
    }
}

/// Mise à jour partielle des réglages Spoolman (`PUT /settings/spoolman`).
/// Seuls les champs renseignés sont transmis (le serveur n'écrit que les clés présentes).
public struct SpoolmanSettingsUpdate: Encodable, Sendable, Hashable {
    public var spoolmanEnabled: String?
    public var spoolmanUrl: String?
    public var spoolmanSyncMode: String?
    public var spoolmanDisableWeightSync: String?
    public var spoolmanReportPartialUsage: String?

    public init(
        spoolmanEnabled: Bool? = nil,
        spoolmanUrl: String? = nil,
        spoolmanSyncMode: String? = nil,
        spoolmanDisableWeightSync: Bool? = nil,
        spoolmanReportPartialUsage: Bool? = nil
    ) {
        self.spoolmanEnabled = spoolmanEnabled.map(SpoolmanSettings.flag)
        self.spoolmanUrl = spoolmanUrl
        self.spoolmanSyncMode = spoolmanSyncMode
        self.spoolmanDisableWeightSync = spoolmanDisableWeightSync.map(SpoolmanSettings.flag)
        self.spoolmanReportPartialUsage = spoolmanReportPartialUsage.map(SpoolmanSettings.flag)
    }

    private enum CodingKeys: String, CodingKey {
        case spoolmanEnabled, spoolmanUrl, spoolmanSyncMode
        case spoolmanDisableWeightSync, spoolmanReportPartialUsage
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(spoolmanEnabled, forKey: .spoolmanEnabled)
        try container.encodeIfPresent(spoolmanUrl, forKey: .spoolmanUrl)
        try container.encodeIfPresent(spoolmanSyncMode, forKey: .spoolmanSyncMode)
        try container.encodeIfPresent(spoolmanDisableWeightSync, forKey: .spoolmanDisableWeightSync)
        try container.encodeIfPresent(spoolmanReportPartialUsage, forKey: .spoolmanReportPartialUsage)
    }
}
