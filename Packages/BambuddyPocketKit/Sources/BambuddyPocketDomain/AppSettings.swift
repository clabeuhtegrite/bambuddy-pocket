// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Réglages serveur (`GET /settings/`). Sous-ensemble robuste des champs utiles à l'app mobile :
/// langue, devise, imprimante par défaut, coûts (filament / énergie). Les très nombreux autres
/// champs (LDAP, MQTT, Obico, drying…) sont ignorés ici — clés inconnues tolérées au décodage.
public struct AppSettings: Codable, Sendable, Hashable {
    /// Code de langue de l'interface serveur (`en`, `fr`, `es`, `de`…).
    public var language: String?
    /// Code de langue des notifications.
    public var notificationLanguage: String?
    /// Code devise ISO (`USD`, `EUR`…), utilisé pour les coûts.
    public var currency: String?
    /// Identifiant de l'imprimante par défaut (file/raccourcis), ou `nil` si non défini.
    public var defaultPrinterID: Int?
    /// Coût de filament par défaut (par kg) dans la devise courante.
    public var defaultFilamentCost: Double?
    /// Coût de l'électricité (par kWh) dans la devise courante.
    public var energyCostPerKwh: Double?

    public init(
        language: String? = nil,
        notificationLanguage: String? = nil,
        currency: String? = nil,
        defaultPrinterID: Int? = nil,
        defaultFilamentCost: Double? = nil,
        energyCostPerKwh: Double? = nil
    ) {
        self.language = language
        self.notificationLanguage = notificationLanguage
        self.currency = currency
        self.defaultPrinterID = defaultPrinterID
        self.defaultFilamentCost = defaultFilamentCost
        self.energyCostPerKwh = energyCostPerKwh
    }

    private enum CodingKeys: String, CodingKey {
        case language
        case notificationLanguage
        case currency
        case defaultPrinterID = "defaultPrinterId"
        case defaultFilamentCost
        case energyCostPerKwh
    }
}

/// Mise à jour partielle des réglages (`PATCH /settings/`). Seuls les champs non-`nil` sont encodés
/// (le serveur applique `exclude_unset`), pour ne pas écraser les nombreux autres réglages.
public struct AppSettingsUpdate: Encodable, Sendable, Hashable {
    public var language: String?
    public var notificationLanguage: String?
    public var currency: String?
    public var defaultPrinterID: Int?
    public var defaultFilamentCost: Double?
    public var energyCostPerKwh: Double?

    public init(
        language: String? = nil,
        notificationLanguage: String? = nil,
        currency: String? = nil,
        defaultPrinterID: Int? = nil,
        defaultFilamentCost: Double? = nil,
        energyCostPerKwh: Double? = nil
    ) {
        self.language = language
        self.notificationLanguage = notificationLanguage
        self.currency = currency
        self.defaultPrinterID = defaultPrinterID
        self.defaultFilamentCost = defaultFilamentCost
        self.energyCostPerKwh = energyCostPerKwh
    }

    private enum CodingKeys: String, CodingKey {
        case language
        case notificationLanguage
        case currency
        case defaultPrinterID = "defaultPrinterId"
        case defaultFilamentCost
        case energyCostPerKwh
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(notificationLanguage, forKey: .notificationLanguage)
        try container.encodeIfPresent(currency, forKey: .currency)
        try container.encodeIfPresent(defaultPrinterID, forKey: .defaultPrinterID)
        try container.encodeIfPresent(defaultFilamentCost, forKey: .defaultFilamentCost)
        try container.encodeIfPresent(energyCostPerKwh, forKey: .energyCostPerKwh)
    }
}
