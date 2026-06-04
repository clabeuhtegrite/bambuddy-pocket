// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Type de rails/tiges de mouvement (utile pour la maintenance). Miroir de `get_rod_type` amont.
public enum RodType: String, Sendable, Hashable {
    /// Tiges en fibre de carbone (séries X1 / P1, CoreXY).
    case carbon
    /// Tiges en acier trempé (séries P2S / X2D).
    case steelRod = "steel_rod"
    /// Rails linéaires (séries A1 / H2).
    case linearRail = "linear_rail"
}

/// Capacités matérielles déduites du modèle d'imprimante.
///
/// Source de vérité : `backend/app/utils/printer_models.py` (frozensets `DUAL_NOZZLE_MODELS`,
/// `ETHERNET_MODELS`, `CARBON_ROD_MODELS`/`STEEL_ROD_MODELS`/`LINEAR_RAIL_MODELS`). Les flags
/// **explicitement listés amont** (`dualNozzle`, `hasEthernet`, `rodType`) en sont le miroir
/// fidèle.
///
/// Les flags **non listés amont** (`heatedChamber`, `hasCamera`) sont déduits de la connaissance
/// produit Bambu Lab et **toujours désactivables par le statut réel** : l'UI ne se fie jamais au
/// seul modèle, elle confronte la capacité au champ effectivement exposé (cf. `PrinterDetailView`).
/// Hypothèses tolérantes documentées par flag ci-dessous.
public struct PrinterCapabilities: Sendable, Hashable {
    /// Double extrudeur (familles H2D / X2D). Miroir de `DUAL_NOZZLE_MODELS`.
    public let dualNozzle: Bool

    /// Port ethernet présent. Miroir de `ETHERNET_MODELS` (X1/P1P/A1/A1 Mini en sont exclus).
    public let hasEthernet: Bool

    /// Type de rails/tiges. Miroir de `get_rod_type` ; `nil` pour un modèle inconnu.
    public let rodType: RodType?

    /// Chambre **chauffée** (séchage actif de chambre / pilotage de température de chambre).
    ///
    /// ⚠️ Hypothèse tolérante (non listée amont) : on ne marque chauffée que les modèles qui
    /// pilotent activement la chambre — **H2D / H2D Pro / X2D** (conduit d'air chauffant +
    /// `airduct_mode`). X1/X1C/X1E ont une chambre **fermée et instrumentée** (température lue)
    /// mais pas activement chauffée : l'UI affiche quand même la température de chambre dès que le
    /// statut l'expose (champ `chamber`), indépendamment de ce flag. Ce flag ne gouverne que les
    /// **contrôles** de chauffage de chambre, pas l'affichage de lecture.
    public let heatedChamber: Bool

    /// Caméra embarquée disponible.
    ///
    /// ⚠️ Hypothèse tolérante (non listée amont) : tous les modèles Bambu Lab actuels embarquent
    /// une caméra (résolutions variables, non modélisées faute de source). On reste donc permissif
    /// (`true` par défaut) et l'UI confronte au champ `ipcam` du statut réel pour décider de
    /// l'affichage. Aucun modèle connu ne nécessite `false` ; conservé pour un futur modèle sans
    /// caméra qui exposerait `ipcam:false`.
    public let hasCamera: Bool

    /// Types d'AMS pris en charge par le modèle (déduit du type de rails / gamme).
    ///
    /// ⚠️ Hypothèse tolérante (non listée amont) : la gamme A1 utilise l'**AMS Lite** (`amsLite`),
    /// les autres l'**AMS standard** / **AMS 2 Pro** + **AMS-HT** (`standard`, `ht`). L'UI ne s'en
    /// sert que pour un libellé par défaut ; le **type réel** est toujours lu sur l'unité AMS du
    /// statut (`is_ams_ht` / `module_type`), qui prime.
    public let amsKinds: Set<AMSKind>

    /// Nombre de buses (1 ou 2). Dérivé de `dualNozzle`.
    public var nozzleCount: Int {
        dualNozzle ? 2 : 1
    }

    /// Le modèle n'accepte **que** l'AMS Lite (gamme A1) ? Sert à résoudre le type d'une unité AMS
    /// que le statut ne tagge pas distinctement (cf. `AMSUnit.resolvedKind`).
    public var amsOnlyLite: Bool {
        amsKinds == [.amsLite]
    }

    /// Le modèle prend-il en charge l'AMS-HT chauffante ?
    public var supportsHeatedAMS: Bool {
        amsKinds.contains(.ht)
    }

    public init(
        dualNozzle: Bool,
        hasEthernet: Bool,
        rodType: RodType?,
        heatedChamber: Bool,
        hasCamera: Bool,
        amsKinds: Set<AMSKind>
    ) {
        self.dualNozzle = dualNozzle
        self.hasEthernet = hasEthernet
        self.rodType = rodType
        self.heatedChamber = heatedChamber
        self.hasCamera = hasCamera
        self.amsKinds = amsKinds
    }

    // MARK: Frozensets amont (miroir de printer_models.py, formes normalisées)

    /// `DUAL_NOZZLE_MODELS` (noms courts + codes internes, normalisés).
    static let dualNozzleModels: Set<String> = [
        "H2D", "H2DPRO", "H2C", "X2D",
        "O1D", "O1E", "O2D", "O1C", "O1C2", "N6"
    ]

    /// `ETHERNET_MODELS` (noms courts + codes internes, normalisés).
    static let ethernetModels: Set<String> = [
        "X1C", "X1E", "X2D", "P1S", "P2S", "H2D", "H2DPRO", "H2C", "H2S",
        "C11", "C13", "N6", "O1D", "O1E", "O2D", "O1C", "O1C2", "O1S"
    ]

    /// `CARBON_ROD_MODELS`.
    static let carbonRodModels: Set<String> = [
        "X1", "X1C", "X1E", "P1P", "P1S",
        "C11", "C12", "C13"
    ]

    /// `STEEL_ROD_MODELS`.
    static let steelRodModels: Set<String> = [
        "P2S", "X2D",
        "N7", "N6"
    ]

    /// `LINEAR_RAIL_MODELS`.
    static let linearRailModels: Set<String> = [
        "A1", "A1MINI", "H2D", "H2DPRO", "H2C", "H2S",
        "N1", "N2S", "A04", "A11", "A12", "O1D", "O1E", "O2D", "O1C", "O1C2", "O1S"
    ]

    /// Modèles à chambre activement chauffée (hypothèse tolérante, cf. `heatedChamber`).
    static let heatedChamberModels: Set<String> = [
        "H2D", "H2DPRO", "X2D",
        "O1D", "O1E", "O2D", "N6"
    ]

    /// Modèles de la gamme A1 (AMS Lite). Formes normalisées.
    static let amsLiteModels: Set<String> = [
        "A1", "A1MINI",
        "N1", "N2S", "A04", "A11", "A12"
    ]

    // MARK: Dérivation

    /// Capacités prudentes par défaut pour un **modèle inconnu/futur** : mono-buse, pas d'ethernet,
    /// pas de chambre chauffée, caméra présumée disponible (confrontée au statut), AMS standard.
    /// Rien ne casse ; l'UI s'appuie ensuite sur les champs réels du statut.
    public static let unknown = PrinterCapabilities(
        dualNozzle: false,
        hasEthernet: false,
        rodType: nil,
        heatedChamber: false,
        hasCamera: true,
        amsKinds: [.standard]
    )

    /// Déduit les capacités d'un modèle (miroir des helpers `is_dual_nozzle_model`,
    /// `has_ethernet`, `get_rod_type`). Un `nil` (modèle absent) → `.unknown`.
    public static func forModel(_ model: PrinterModel?) -> PrinterCapabilities {
        guard let model else {
            return .unknown
        }
        let key = model.normalized
        let dual = dualNozzleModels.contains(key)
        let ethernet = ethernetModels.contains(key)
        let rod = resolveRodType(key)
        let heated = heatedChamberModels.contains(key)
        let ams = resolveAMSKinds(key, rodType: rod)
        return PrinterCapabilities(
            dualNozzle: dual,
            hasEthernet: ethernet,
            rodType: rod,
            heatedChamber: heated,
            hasCamera: true,
            amsKinds: ams
        )
    }

    /// Déduit les capacités directement depuis une valeur brute (nom/code/série) via `resolve`.
    public static func forRawModel(_ raw: String?) -> PrinterCapabilities {
        forModel(PrinterModel.resolve(raw))
    }

    private static func resolveRodType(_ key: String) -> RodType? {
        if carbonRodModels.contains(key) {
            return .carbon
        }
        if steelRodModels.contains(key) {
            return .steelRod
        }
        if linearRailModels.contains(key) {
            return .linearRail
        }
        return nil
    }

    private static func resolveAMSKinds(_ key: String, rodType: RodType?) -> Set<AMSKind> {
        if amsLiteModels.contains(key) {
            return [.amsLite]
        }
        // Modèle inconnu/futur (rodType nil) : prudence, AMS standard seulement.
        guard rodType != nil else {
            return [.standard]
        }
        // Standard + AMS-HT pour les gammes connues qui l'acceptent (H2D/X2D, X1/P1 modernes).
        return [.standard, .ht]
    }
}
