// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Type d'une unité AMS, déduit du statut réel (`is_ams_ht` / `module_type`) ou du modèle.
///
/// - `standard` : AMS standard / AMS 2 Pro (4 slots, `module_type` n3f/typiquement absent).
/// - `amsLite` : AMS Lite des A1 / A1 Mini (4 slots externes, sans capot, non chauffant).
/// - `ht` : AMS-HT chauffante (1 slot, séchage actif, `is_ams_ht:true`, `module_type:n3s`,
///   id matériel 128 observé sur X2D réelle).
///
/// Le `module_type` est la source la plus fiable côté statut ; `is_ams_ht` le confirme pour la HT.
public enum AMSKind: String, Sendable, Hashable, CaseIterable {
    case standard
    case amsLite
    case ht

    /// Détecte le type d'une unité AMS depuis ses champs de statut.
    ///
    /// Priorité : `is_ams_ht`/`module_type:n3s` → `.ht` ; `module_type:n3l` → `.amsLite` ;
    /// sinon `.standard`. Tolérant : champs absents → `.standard`.
    public static func detect(isAmsHt: Bool?, moduleType: String?) -> AMSKind {
        let type = moduleType?.lowercased()
        if isAmsHt == true || type == "n3s" {
            return .ht
        }
        if type == "n3l" || type == "ams_lite" {
            return .amsLite
        }
        return .standard
    }
}

public extension AMSUnit {
    /// Type d'AMS déduit des champs réels de l'unité (prime sur la capacité modèle).
    var kind: AMSKind {
        AMSKind.detect(isAmsHt: isAmsHt, moduleType: moduleType)
    }

    /// L'unité est-elle une AMS-HT chauffante (séchage/humidité pertinents) ?
    var isHeatedAMS: Bool {
        kind == .ht
    }
}
