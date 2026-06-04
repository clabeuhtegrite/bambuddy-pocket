// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Entrée du catalogue de filaments (`GET /filament-catalog/`) : référence type/marque avec
/// coût, températures et propriétés. Sous-ensemble robuste — clés inconnues ignorées.
public struct FilamentCatalogEntry: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String
    public var type: String?
    public var brand: String?
    public var colorHex: String?
    public var costPerKg: Double?
    public var currency: String?
    public var density: Double?
    public var printTempMin: Int?
    public var printTempMax: Int?
    public var bedTempMin: Int?
    public var bedTempMax: Int?

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }

    /// Plage de température de buse formatée (« 260–280 °C »), si disponible.
    public var nozzleTempRange: String? {
        Self.range(printTempMin, printTempMax)
    }

    /// Plage de température de plateau formatée, si disponible.
    public var bedTempRange: String? {
        Self.range(bedTempMin, bedTempMax)
    }

    private static func range(_ low: Int?, _ high: Int?) -> String? {
        switch (low, high) {
        case let (low?, high?): "\(low)–\(high) °C"
        case let (low?, nil): "\(low) °C"
        case let (nil, high?): "\(high) °C"
        default: nil
        }
    }
}
