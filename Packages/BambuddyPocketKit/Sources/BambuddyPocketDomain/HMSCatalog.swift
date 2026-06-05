// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Outils de présentation/filtrage des erreurs HMS (Health Management System) Bambu, alignés sur le
/// **contrat amont** (Bambuddy `backend/app/main.py`).
///
/// Trois besoins sont couverts ici :
/// 1. **Code court canonique** `MMMM_CCCC` (cf. `_hms_short_code` amont), pour résoudre un libellé
///    humain plutôt que d'afficher le code hexadécimal brut (`0x30027`) à l'utilisateur.
/// 2. **Table de raisons** (`_HMS_FAILURE_REASONS`) : libellés lisibles pour les codes connus.
/// 3. **Lien wiki Bambu** pour qu'un code inconnu mais légitime reste actionnable.
public enum HMSCatalog {
    /// Code court canonique `MMMM_CCCC` à partir d'`attr`/`code` (cf. `_hms_short_code` amont) :
    /// `f"{(attr>>16)&0xFFFF:04X}_{code&0xFFFF:04X}"`.
    ///
    /// Retourne `nil` si l'`attr` est absent (on ne peut pas reconstituer le module) — l'appelant
    /// retombera alors sur un affichage générique.
    public static func shortCode(attr: Int?, code: String) -> String? {
        guard let attr, let rawCode = parseCode(code) else { return nil }
        let module = (attr >> 16) & 0xFFFF
        let detail = rawCode & 0xFFFF
        return String(format: "%04X_%04X", module, detail)
    }

    /// Libellé humain d'un code HMS, **dans l'ordre de préférence** :
    /// 1. raison connue de la table (`Layer shift`, `Filament runout`…) ;
    /// 2. à défaut, format lisible « HMS MMMM_CCCC » (jamais le `0x…` brut) ;
    /// 3. en dernier recours (pas d'`attr`), le code tel quel.
    ///
    /// La traduction des raisons connues est laissée à la couche présentation (clés stables).
    public static func displayCode(attr: Int?, code: String) -> String {
        if let short = shortCode(attr: attr, code: code) {
            return "HMS \(short)"
        }
        return code
    }

    /// Clé stable de raison connue (pour i18n côté présentation), ou `nil` si le code est inconnu.
    public static func failureReasonKey(attr: Int?, code: String) -> String? {
        guard let short = shortCode(attr: attr, code: code) else { return nil }
        return failureReasons[short]
    }

    /// Lien wiki Bambu pour le code (page de recherche du code court), ou `nil` si non calculable.
    public static func wikiURL(attr: Int?, code: String) -> URL? {
        guard let short = shortCode(attr: attr, code: code) else { return nil }
        return URL(string: "https://wiki.bambulab.com/en/x1/troubleshooting/hmscode/\(short)")
    }

    /// Sévérité **effective** d'une entrée HMS, conforme à la sémantique réelle observée sur la X2D.
    ///
    /// Le firmware encode la gravité dans le quartet `(attr >> 8) & 0xF` (0…15). Sur la X2D réelle,
    /// le champ `severity` à plat est **atypique** (on a vu `2` et `6` pour des codes purement
    /// informatifs/de statut que la gamme H2D/X2D émet en continu, p. ex. `0x30027`). On privilégie
    /// donc la gravité encodée dans `attr` ; seules les valeurs `1`/`2`/`3` y sont significatives,
    /// toute autre (0, ≥ 4) retombe sur `.info`. À défaut d'`attr`, on retombe sur le champ `severity`.
    public static func effectiveSeverity(attr: Int?, severity: Int?) -> HMSSeverity {
        if let attr {
            return HMSSeverity(code: (attr >> 8) & 0xF)
        }
        return HMSSeverity(code: severity ?? 0)
    }

    // MARK: Interne

    private static func parseCode(_ code: String) -> Int? {
        var string = code
        if string.hasPrefix("0x") || string.hasPrefix("0X") {
            string.removeFirst(2)
        }
        // Certains codes arrivent au format long `MMMM_CCCC_..._...` : on garde le segment détail.
        if string.contains("_") {
            let parts = string.split(separator: "_")
            guard parts.count >= 2, let value = Int(parts[1], radix: 16) else { return nil }
            return value
        }
        return Int(string, radix: 16)
    }

    /// Table des raisons connues (`MMMM_CCCC` → clé i18n stable), recopiée/adaptée de
    /// `_HMS_FAILURE_REASONS` (amont). Volontairement minimale et extensible.
    static let failureReasons: [String: String] = [
        "0300_0100": "hms.reason.layerShift",
        "0300_0200": "hms.reason.filamentRunout",
        "0300_0300": "hms.reason.cloggedNozzle",
        "0700_0100": "hms.reason.bedNotHeating",
        "0700_0200": "hms.reason.nozzleNotHeating",
        "0C00_0100": "hms.reason.firstLayerFailed",
        "1200_0100": "hms.reason.spaghettiDetected"
    ]
}
