// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Libellés localisés pour l'affichage des unités AMS, **adaptatifs au type** (standard / Lite / HT).
enum AMSPresentation {
    /// Titre de section d'une unité selon son type. L'AMS-HT et la standard sont numérotées ;
    /// l'AMS Lite (une seule par A1) ne l'est pas.
    static func title(kind: AMSKind, id: Int) -> String {
        switch kind {
        case .amsLite:
            String(localized: "AMS Lite")
        case .ht:
            // Les AMS-HT ont des id matériels ≥ 128 ; on présente un numéro lisible (1-based).
            String(localized: "AMS-HT \(htDisplayNumber(id))")
        case .standard:
            String(localized: "AMS \(id + 1)")
        }
    }

    /// Numéro lisible (1-based) d'une AMS-HT dont l'id matériel commence à 128.
    private static func htDisplayNumber(_ id: Int) -> Int {
        id >= 128 ? id - 128 + 1 : id + 1
    }
}
