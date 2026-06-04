// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Type d'une unité AMS, déduit du statut réel et, en complément, du modèle.
///
/// Conventions `module_type` **amont** (`bambu_mqtt.py`, `schemas/printer.py`) :
/// - `ams` : AMS d'origine (4 slots) → `.standard`.
/// - `n3f` : AMS 2 Pro (4 slots, H2D/X2D…) → `.standard`.
/// - `n3s` : AMS-HT chauffante (1 slot, id matériel ≥ 128) → `.ht`.
///
/// Amont, l'AMS-HT est aussi reconnue par `is_ams_ht` et par `ams_id >= 128`
/// (`main.py:4268`). On combine ces trois signaux pour une détection robuste.
///
/// ⚠️ **AMS Lite** (gamme A1) : l'amont ne lui attribue pas de `module_type` distinct dans le
/// statut — c'est une **capacité dérivée du modèle** (cf. `PrinterCapabilities.amsKinds`), pas un
/// champ de statut. La détection par statut ci-dessous reconnaît tout de même un éventuel
/// `module_type:n3l`/`ams_lite` (hypothèse tolérante, non sourcée amont) ; en pratique l'UI passe
/// le modèle pour distinguer Lite via `detect(isAmsHt:moduleType:amsID:modelHasOnlyLite:)`.
public enum AMSKind: String, Sendable, Hashable, CaseIterable {
    case standard
    case amsLite
    case ht

    /// Détecte le type d'une unité AMS depuis ses seuls champs de statut.
    ///
    /// Priorité : HT si `is_ams_ht`, `module_type:n3s`, ou `id >= 128` ; `.amsLite` si
    /// `module_type:n3l`/`ams_lite` (hypothèse tolérante) ; sinon `.standard`. Tolérant aux champs
    /// absents → `.standard`.
    public static func detect(isAmsHt: Bool?, moduleType: String?, amsID: Int? = nil) -> AMSKind {
        let type = moduleType?.lowercased()
        if isAmsHt == true || type == "n3s" || (amsID ?? 0) >= 128 {
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
    ///
    /// Combine `is_ams_ht`, `module_type` et l'`id` (≥ 128 → HT, cf. amont).
    var kind: AMSKind {
        AMSKind.detect(isAmsHt: isAmsHt, moduleType: moduleType, amsID: id)
    }

    /// Type effectif en tenant compte du modèle : une unité « standard » sur une imprimante dont
    /// le seul AMS possible est l'AMS Lite (gamme A1) est en réalité une AMS Lite. La détection HT
    /// par champ de statut prime toujours.
    func resolvedKind(modelOnlySupportsLite: Bool) -> AMSKind {
        let detected = kind
        if detected == .standard, modelOnlySupportsLite {
            return .amsLite
        }
        return detected
    }

    /// L'unité est-elle une AMS-HT chauffante (séchage/humidité pertinents) ?
    var isHeatedAMS: Bool {
        kind == .ht
    }
}
