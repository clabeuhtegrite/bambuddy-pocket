// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Statistiques globales d'impression (`GET /archives/stats`, `ArchiveStats`).
///
/// Champs scalaires uniquement (les ventilations par imprimante/filament sont ignorées).
public struct ArchiveStats: Codable, Sendable, Hashable {
    public var totalPrints: Int
    public var successfulPrints: Int
    public var failedPrints: Int
    public var totalPrintTimeHours: Double
    public var totalFilamentGrams: Double
    public var totalCost: Double
    public var totalEnergyKwh: Double?
    public var totalEnergyCost: Double?

    public init(
        totalPrints: Int,
        successfulPrints: Int,
        failedPrints: Int,
        totalPrintTimeHours: Double,
        totalFilamentGrams: Double,
        totalCost: Double,
        totalEnergyKwh: Double? = nil,
        totalEnergyCost: Double? = nil
    ) {
        self.totalPrints = totalPrints
        self.successfulPrints = successfulPrints
        self.failedPrints = failedPrints
        self.totalPrintTimeHours = totalPrintTimeHours
        self.totalFilamentGrams = totalFilamentGrams
        self.totalCost = totalCost
        self.totalEnergyKwh = totalEnergyKwh
        self.totalEnergyCost = totalEnergyCost
    }
}
