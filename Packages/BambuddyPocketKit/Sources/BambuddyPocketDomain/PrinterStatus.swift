// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Températures rapportées par l'imprimante (en °C). Tous champs optionnels selon le modèle.
public struct Temperatures: Codable, Sendable, Hashable {
    public var nozzle: Double?
    public var nozzleTarget: Double?
    /// Seconde buse (modèles double extrudeur : familles H2D / X2D). `nil` sur mono-buse.
    public var nozzle2: Double?
    public var nozzle2Target: Double?
    public var bed: Double?
    public var bedTarget: Double?
    public var chamber: Double?
    public var chamberTarget: Double?

    public init(
        nozzle: Double? = nil,
        nozzleTarget: Double? = nil,
        nozzle2: Double? = nil,
        nozzle2Target: Double? = nil,
        bed: Double? = nil,
        bedTarget: Double? = nil,
        chamber: Double? = nil,
        chamberTarget: Double? = nil
    ) {
        self.nozzle = nozzle
        self.nozzleTarget = nozzleTarget
        self.nozzle2 = nozzle2
        self.nozzle2Target = nozzle2Target
        self.bed = bed
        self.bedTarget = bedTarget
        self.chamber = chamber
        self.chamberTarget = chamberTarget
    }
}

/// Niveau de gravité d'une erreur HMS (interprétation de `severity`).
///
/// Le firmware encode la gravité dans le quartet `(attr >> 8) & 0xF` (0…15) que le serveur
/// relaie tel quel. Seules les valeurs `1` (fatal), `2` (serious) et `3` (common/warning) sont
/// significatives ; **toute autre valeur** (0, ou ≥ 4 comme le `6` observé sur une X2D réelle)
/// est traitée comme **`info`** — c'est le comportement de référence de Bambuddy en amont
/// (`getSeverityInfo` : `case 4`/`default` → Info). On évite ainsi d'afficher « Unknown » pour
/// des gravités parfaitement valides mais hors de la plage 1…3.
public enum HMSSeverity: Sendable, Hashable {
    case fatal
    case serious
    case common
    case info

    public init(code: Int) {
        switch code {
        case 1: self = .fatal
        case 2: self = .serious
        case 3: self = .common
        default: self = .info
        }
    }

    /// Rang de gravité décroissante (`fatal` = plus grave) pour trier/comparer les erreurs.
    public var rank: Int {
        switch self {
        case .fatal: 0
        case .serious: 1
        case .common: 2
        case .info: 3
        }
    }
}

/// Erreur HMS (Health Management System) Bambu. Le code se résout en message via une table
/// embarquée (à ajouter en Phase 1) ; `severity` permet de hiérarchiser l'affichage.
public struct HMSError: Codable, Sendable, Hashable, Identifiable {
    public var code: String
    public var attr: Int?
    public var module: Int?
    public var severity: Int?

    public var id: String {
        code
    }

    /// Sévérité telle qu'exposée par le champ `severity` brut (interprétation directe). Conservée
    /// pour la rétro-compatibilité ; préférer `effectiveSeverity` pour décider d'alarmer.
    public var severityLevel: HMSSeverity {
        HMSSeverity(code: severity ?? 0)
    }

    /// Sévérité **effective** retenue pour décider d'afficher/notifier, dérivée en priorité du
    /// quartet `(attr >> 8) & 0xF` (sémantique réelle X2D), cf. `HMSCatalog.effectiveSeverity`.
    public var effectiveSeverity: HMSSeverity {
        HMSCatalog.effectiveSeverity(attr: attr, severity: severity)
    }

    /// Ce code est-il **reconnu** par la web UI (présent dans son catalogue) ? Les codes inconnus
    /// (calibration/vision/statut émis en continu, p. ex. `0500_0070`) sont masqués comme côté web.
    public var isKnown: Bool {
        HMSCatalog.isKnown(attr: attr, code: code)
    }

    /// Cette entrée doit-elle déclencher une alarme (affichage erreur + notification) ?
    ///
    /// Réplique le double filtre de la web UI : **(1)** le code doit être *connu*
    /// (`filterKnownHMSErrors`), sinon il est masqué quelle que soit sa gravité — c'est ce qui élimine
    /// les faux positifs `0C00_0015`/`0500_0070`/`0503_0027` ; **(2)** la gravité effective doit être
    /// ≥ serious (`severity >= 2` amont), pour ne pas alarmer sur de l'informatif connu.
    public var isAlarming: Bool {
        guard isKnown else { return false }
        switch effectiveSeverity {
        case .fatal, .serious: return true
        case .common, .info: return false
        }
    }

    /// Code court canonique `MMMM_CCCC` (ou `nil` si non calculable faute d'`attr`).
    public var shortCode: String? {
        HMSCatalog.shortCode(attr: attr, code: code)
    }

    /// Libellé affichable lisible (« HMS 0503_0027 » plutôt que `0x30027`).
    public var displayCode: String {
        HMSCatalog.displayCode(attr: attr, code: code)
    }

    /// Clé i18n d'une raison connue (Layer shift, Filament runout…), ou `nil`.
    public var failureReasonKey: String? {
        HMSCatalog.failureReasonKey(attr: attr, code: code)
    }

    /// Lien wiki Bambu pour ce code (ou `nil`).
    public var wikiURL: URL? {
        HMSCatalog.wikiURL(attr: attr, code: code)
    }

    public init(code: String, attr: Int? = nil, module: Int? = nil, severity: Int? = nil) {
        self.code = code
        self.attr = attr
        self.module = module
        self.severity = severity
    }
}

/// Un slot de filament (plateau AMS ou bobine externe).
public struct AMSTray: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var trayColor: String?
    public var trayType: String?
    public var traySubBrands: String?
    public var trayIdName: String?
    public var remain: Int?
    public var tagUid: String?
    public var trayUuid: String?
    public var nozzleTempMin: Int?
    public var nozzleTempMax: Int?
    public var state: Int?

    public init(id: Int) {
        self.id = id
    }
}

/// Une unité AMS (ou AMS-HT). Contient ses plateaux (`tray`).
public struct AMSUnit: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var humidity: Int?
    public var temp: Double?
    public var isAmsHt: Bool?
    public var dryTime: Int?
    public var dryStatus: Int?
    public var moduleType: String?
    public var serialNumber: String?
    public var swVer: String?
    public var tray: [AMSTray]?

    public init(id: Int) {
        self.id = id
    }
}

/// Options d'impression / détection IA (xcam) rapportées dans le statut (`print_options`).
/// Sous-ensemble robuste : tous les champs sont optionnels et tolérants aux évolutions de l'API.
public struct PrintOptions: Codable, Sendable, Hashable {
    public var spaghettiDetector: Bool?
    public var firstLayerInspector: Bool?
    public var printingMonitor: Bool?
    public var buildplateMarkerDetector: Bool?
    public var allowSkipParts: Bool?
    public var nozzleClumpingDetector: Bool?
    public var pileupDetector: Bool?
    public var airprintDetector: Bool?
    public var autoRecoveryStepLoss: Bool?
    public var filamentTangleDetect: Bool?
    /// Sensibilité de la détection de spaghetti (`low`/`medium`/`high`/`never_halt`).
    public var haltPrintSensitivity: String?

    public init(
        spaghettiDetector: Bool? = nil,
        firstLayerInspector: Bool? = nil,
        printingMonitor: Bool? = nil,
        buildplateMarkerDetector: Bool? = nil,
        allowSkipParts: Bool? = nil,
        nozzleClumpingDetector: Bool? = nil,
        pileupDetector: Bool? = nil,
        airprintDetector: Bool? = nil,
        autoRecoveryStepLoss: Bool? = nil,
        filamentTangleDetect: Bool? = nil,
        haltPrintSensitivity: String? = nil
    ) {
        self.spaghettiDetector = spaghettiDetector
        self.firstLayerInspector = firstLayerInspector
        self.printingMonitor = printingMonitor
        self.buildplateMarkerDetector = buildplateMarkerDetector
        self.allowSkipParts = allowSkipParts
        self.nozzleClumpingDetector = nozzleClumpingDetector
        self.pileupDetector = pileupDetector
        self.airprintDetector = airprintDetector
        self.autoRecoveryStepLoss = autoRecoveryStepLoss
        self.filamentTangleDetect = filamentTangleDetect
        self.haltPrintSensitivity = haltPrintSensitivity
    }
}

/// État temps réel d'une imprimante (cf. `docs/bambuddy-api.md` §5.1).
///
/// Sur-ensemble REST (`GET /printers/{id}/status`) ; le WebSocket pousse un **sous-ensemble**
/// (les champs absents restent `nil`). Tous les champs sont optionnels pour permettre la
/// **fusion** des deltas WebSocket et la tolérance aux évolutions de l'API.
public struct PrinterStatus: Codable, Sendable, Hashable {
    public var name: String?
    public var model: String?
    public var connected: Bool?
    public var state: PrinterState?

    // Impression en cours
    public var currentPrint: String?
    public var subtaskName: String?
    public var gcodeFile: String?
    public var progress: Double?
    public var remainingTime: Int?
    public var layerNum: Int?
    public var totalLayers: Int?
    public var coverUrl: String?
    public var currentArchiveId: Int?
    public var currentPlateId: Int?

    // Capteurs
    public var temperatures: Temperatures?
    public var hmsErrors: [HMSError]?
    public var ams: [AMSUnit]?
    public var vtTray: [AMSTray]?
    public var wifiSignal: Int?
    public var wiredNetwork: Bool?
    public var doorOpen: Bool?

    // Ventilateurs
    public var coolingFanSpeed: Int?
    public var bigFan1Speed: Int?
    public var bigFan2Speed: Int?
    public var heatbreakFanSpeed: Int?

    // Divers
    public var chamberLight: Bool?
    public var activeExtruder: Int?
    public var speedLevel: Int?
    public var stgCur: Int?
    public var stgCurName: String?
    public var printableObjectsCount: Int?
    public var awaitingPlateClear: Bool?
    public var supportsDrying: Bool?
    public var firmwareVersion: String?
    public var sdcard: Bool?
    public var timelapse: Bool?
    public var ipcam: Bool?
    public var printOptions: PrintOptions?
    /// Mode du conduit d'air (modèles compatibles) : 0 = refroidissement, 1 = chauffage.
    public var airductMode: Int?

    public init() {}

    // MARK: Helpers UI

    /// Une impression est-elle active (en cours / préparation / pause) ?
    public var isPrinting: Bool {
        state?.isActivePrint ?? false
    }

    /// État **vivant de la machine** à afficher comme statut de connexion, distinct du *résultat
    /// du dernier print*.
    ///
    /// Le firmware conserve `state == FAILED` (ou `FINISH`) **après** une impression terminée :
    /// c'est le résultat de ce print, pas l'état courant de la machine. Tant que l'imprimante est
    /// **connectée** et qu'aucune impression n'est active, elle est en réalité **au repos** (prête) —
    /// elle continue d'ailleurs de pousser du temps réel (températures, extrudeur actif). Afficher
    /// alors un badge rouge « Échec » comme statut global est trompeur (l'imprimante n'est pas en
    /// panne). On déclasse donc un `FAILED` résiduel en `.idle` dans ce cas précis.
    ///
    /// On ne touche **pas** : aux états d'impression actifs, à une imprimante déconnectée (le badge
    /// « Hors ligne » prime en amont), ni à `FINISH` (un « Terminé » vert reste une information
    /// neutre et exacte sur le dernier print).
    public var liveState: PrinterState? {
        guard connected != false, state == .failed, !isPrinting else {
            return state
        }
        return .idle
    }

    /// Progression en fraction (0…1) si disponible.
    public var progressFraction: Double? {
        progress.map { max(0, min(1, $0 / 100)) }
    }

    /// Erreurs HMS **alarmantes** (gravité effective ≥ serious) : seules celles-ci doivent être
    /// affichées comme erreur et notifiées. Les codes informatifs/de statut (que la gamme H2D/X2D
    /// émet en continu) sont filtrés, comme le fait l'amont (`severity >= 2`).
    public var alarmingErrors: [HMSError] {
        (hmsErrors ?? []).filter(\.isAlarming)
    }

    /// L'imprimante signale-t-elle au moins une erreur HMS **alarmante** ?
    public var hasActiveErrors: Bool {
        !alarmingErrors.isEmpty
    }

    /// Étape courante (`stg_cur_name`) à n'afficher **que** lorsqu'une impression est active.
    ///
    /// Le firmware laisse une valeur résiduelle dans `stg_cur_name` (p. ex. « Printing ») même
    /// après la fin d'une impression. L'afficher quand l'imprimante est inactive/déconnectée
    /// donnerait une indication trompeuse (« Inactif » + « Printing »). On ne renvoie donc l'étape
    /// que pour un état d'impression actif (en cours / préparation / pause) et non vide.
    public var displayableStage: String? {
        guard isPrinting, let stage = stgCurName, !stage.isEmpty else {
            return nil
        }
        return stage
    }

    /// Erreur HMS **alarmante** la plus grave (pour mise en avant), ou `nil` si aucune n'alarme.
    public var mostSevereError: HMSError? {
        alarmingErrors.min { lhs, rhs in lhs.effectiveSeverity.rank < rhs.effectiveSeverity.rank }
    }

    /// Modèle normalisé déduit du champ `model` du statut, **s'il est présent**.
    ///
    /// ⚠️ Le statut (`GET /printers/{id}/status`) n'expose pas toujours `model` — c'est le
    /// `Printer` (liste) qui le porte de façon fiable. L'app combine donc `Printer.capabilities`
    /// (modèle) avec ce que le statut expose réellement. Utiliser `Printer.printerModel` pour la
    /// source de vérité du modèle.
    public var statusModel: PrinterModel? {
        PrinterModel.resolve(model)
    }

    /// Capacités déduites du seul statut (peut être `.unknown` si le statut n'a pas de modèle).
    /// Préférer `Printer.capabilities` quand on dispose du `Printer`.
    public var statusCapabilities: PrinterCapabilities {
        PrinterCapabilities.forModel(statusModel)
    }

    /// Le statut expose-t-il une donnée de seconde buse (présence effective, indépendamment du
    /// modèle) ? Sert de signal complémentaire à `PrinterCapabilities.dualNozzle`.
    public var statusReportsSecondNozzle: Bool {
        temperatures?.nozzle2 != nil || temperatures?.nozzle2Target != nil
    }

    /// L'UI doit-elle afficher la seconde buse pour ces capacités ?
    ///
    /// `true` si le modèle est double extrudeur **et** que le statut expose au moins une donnée de
    /// seconde buse (température ou extrudeur actif). Robuste : un modèle dual sans données de
    /// seconde buse (firmware ancien) n'affiche rien d'erroné.
    public func showsSecondNozzle(capabilities: PrinterCapabilities) -> Bool {
        capabilities.dualNozzle && (statusReportsSecondNozzle || activeExtruder != nil)
    }
}
