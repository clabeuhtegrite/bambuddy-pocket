// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Une bobine de filament de l'inventaire (`GET /inventory/spools`, `SpoolResponse`).
///
/// Sous-ensemble robuste limité à l'affichage. Les champs non modélisés sont ignorés au décodage.
public struct Spool: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var material: String
    public var subtype: String?
    public var brand: String?
    public var colorName: String?
    public var rgba: String?
    public var labelWeight: Int?
    public var weightUsed: Double?
    public var costPerKg: Double?
    public var storageLocation: String?
    public var category: String?
    public var note: String?

    public init(id: Int, material: String) {
        self.id = id
        self.material = material
    }

    /// Libellé : marque + matériau (+ sous-type).
    public var displayName: String {
        var parts: [String] = []
        if let brand, !brand.isEmpty {
            parts.append(brand)
        }
        parts.append(material)
        if let subtype, !subtype.isEmpty {
            parts.append(subtype)
        }
        return parts.joined(separator: " ")
    }

    /// Grammes restants (poids étiquette − poids utilisé), si connus.
    public var remainingGrams: Double? {
        guard let labelWeight else {
            return nil
        }
        return max(0, Double(labelWeight) - (weightUsed ?? 0))
    }

    /// Fraction restante (0…1), si le poids étiquette est connu.
    public var remainingFraction: Double? {
        guard let labelWeight, labelWeight > 0, let remaining = remainingGrams else {
            return nil
        }
        return min(1, max(0, remaining / Double(labelWeight)))
    }
}
