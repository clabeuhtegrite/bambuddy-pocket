// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Référence à un préréglage (préset) de découpe, consciente de sa source.
///
/// La modale de découpe propose des présets issus de trois tiers (cloud / local / standard) ; au
/// moment de soumettre, le client envoie un de ces objets par emplacement (imprimante, process,
/// filament) pour que le serveur sache où récupérer le contenu du préset (`PresetRef` amont).
public struct SlicePresetRef: Codable, Sendable, Hashable {
    /// Tier de provenance du préset.
    public enum Source: String, Codable, Sendable, Hashable {
        case cloud
        case local
        case standard
    }

    public var source: Source
    /// Identifiant opaque : `setting_id` cloud, id de ligne DB local (stringifié) ou nom du préset
    /// standard. Le client le traite comme opaque.
    public var id: String

    public init(source: Source, id: String) {
        self.source = source
        self.id = id
    }
}

/// Un préset unitaire (imprimante / process / filament) renvoyé par `GET /slicer/presets`.
public struct UnifiedPreset: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var source: SlicePresetRef.Source
    /// Renseignés pour l'emplacement filament uniquement (pré-sélection multi-couleur).
    public var filamentType: String?
    public var filamentColour: String?
    /// Liste de noms de présets imprimante avec lesquels ce process/filament se déclare compatible
    /// (renseigné pour le tier local ; `nil` pour cloud/standard).
    public var compatiblePrinters: [String]?

    public init(
        id: String,
        name: String,
        source: SlicePresetRef.Source,
        filamentType: String? = nil,
        filamentColour: String? = nil,
        compatiblePrinters: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.filamentType = filamentType
        self.filamentColour = filamentColour
        self.compatiblePrinters = compatiblePrinters
    }

    /// Référence de découpe correspondant à ce préset (à envoyer dans une `SliceRequest`).
    public var ref: SlicePresetRef {
        SlicePresetRef(source: source, id: id)
    }
}

/// Les trois emplacements de présets, dans l'ordre utilisé par Bambu Studio / OrcaSlicer.
public struct UnifiedPresetsBySlot: Codable, Sendable, Hashable {
    public var printer: [UnifiedPreset]
    public var process: [UnifiedPreset]
    public var filament: [UnifiedPreset]

    public init(
        printer: [UnifiedPreset] = [],
        process: [UnifiedPreset] = [],
        filament: [UnifiedPreset] = []
    ) {
        self.printer = printer
        self.process = process
        self.filament = filament
    }
}

/// Réponse de `GET /slicer/presets` : présets par tier (dédupliqués par nom, cloud > local >
/// standard) + statut de l'accès cloud.
public struct UnifiedPresetsResponse: Codable, Sendable, Hashable {
    /// État de l'accès aux présets cloud (explique pourquoi le tier cloud peut être vide).
    public enum CloudStatus: String, Codable, Sendable, Hashable {
        case ok
        case notAuthenticated = "not_authenticated"
        case expired
        case unreachable
    }

    public var cloud: UnifiedPresetsBySlot
    public var local: UnifiedPresetsBySlot
    public var standard: UnifiedPresetsBySlot
    public var cloudStatus: CloudStatus

    public init(
        cloud: UnifiedPresetsBySlot = UnifiedPresetsBySlot(),
        local: UnifiedPresetsBySlot = UnifiedPresetsBySlot(),
        standard: UnifiedPresetsBySlot = UnifiedPresetsBySlot(),
        cloudStatus: CloudStatus = .ok
    ) {
        self.cloud = cloud
        self.local = local
        self.standard = standard
        self.cloudStatus = cloudStatus
    }

    /// Tous les présets imprimante (cloud puis local puis standard), pour alimenter un menu unique.
    public var allPrinters: [UnifiedPreset] {
        cloud.printer + local.printer + standard.printer
    }

    /// Tous les présets process, tiers concaténés.
    public var allProcesses: [UnifiedPreset] {
        cloud.process + local.process + standard.process
    }

    /// Tous les présets filament, tiers concaténés.
    public var allFilaments: [UnifiedPreset] {
        cloud.filament + local.filament + standard.filament
    }

    /// `true` quand aucun préset n'est disponible dans aucun tier : la découpe ne peut pas être
    /// soumise (l'UI doit afficher une explication plutôt qu'un formulaire inutilisable).
    public var isEmpty: Bool {
        allPrinters.isEmpty && allProcesses.isEmpty && allFilaments.isEmpty
    }
}

/// Corps de `POST /library/files/{id}/slice` (`SliceRequest` amont, forme « source-aware »).
public struct SliceRequest: Codable, Sendable, Hashable {
    public var printerPreset: SlicePresetRef
    public var processPreset: SlicePresetRef
    /// Un préset filament par emplacement AMS utilisé par la plaque source (ordre significatif).
    public var filamentPresets: [SlicePresetRef]
    /// Numéro de plaque à trancher. `nil` ⇒ plaque 1 ; `0` ⇒ toutes les plaques ; `>= 1` ⇒ cette
    /// plaque.
    public var plate: Int?
    /// `true` pour demander une réponse 3MF avec G-code embarqué plutôt que du G-code brut.
    public var export3mf: Bool

    public init(
        printerPreset: SlicePresetRef,
        processPreset: SlicePresetRef,
        filamentPresets: [SlicePresetRef],
        plate: Int? = nil,
        export3mf: Bool = true
    ) {
        self.printerPreset = printerPreset
        self.processPreset = processPreset
        self.filamentPresets = filamentPresets
        self.plate = plate
        self.export3mf = export3mf
    }

    /// `convertToSnakeCase` n'insère pas de séparateur avant un chiffre (`export3mf` →
    /// `export3mf`), alors que le serveur attend `export_3mf`. On force donc les clés
    /// explicitement (les autres suivent la conversion automatique snake_case).
    private enum CodingKeys: String, CodingKey {
        case printerPreset = "printer_preset"
        case processPreset = "process_preset"
        case filamentPresets = "filament_presets"
        case plate
        case export3mf = "export_3mf"
    }
}

/// Réponse immédiate de `POST /library/files/{id}/slice` : un job en file (202).
public struct SliceJobHandle: Codable, Sendable, Hashable {
    public var jobId: Int
    public var status: String
    public var statusUrl: String?

    public init(jobId: Int, status: String, statusUrl: String? = nil) {
        self.jobId = jobId
        self.status = status
        self.statusUrl = statusUrl
    }
}

/// Résultat d'une découpe réussie (incrusté dans `SliceJob.result`). Le fichier tranché atterrit
/// dans la bibliothèque (même dossier que la source).
public struct SliceResult: Codable, Sendable, Hashable {
    public var libraryFileId: Int?
    public var name: String?
    public var printTimeSeconds: Int?
    public var filamentUsedG: Double?
    public var filamentUsedMm: Double?
    public var usedEmbeddedSettings: Bool?

    public init(
        libraryFileId: Int? = nil,
        name: String? = nil,
        printTimeSeconds: Int? = nil,
        filamentUsedG: Double? = nil,
        filamentUsedMm: Double? = nil,
        usedEmbeddedSettings: Bool? = nil
    ) {
        self.libraryFileId = libraryFileId
        self.name = name
        self.printTimeSeconds = printTimeSeconds
        self.filamentUsedG = filamentUsedG
        self.filamentUsedMm = filamentUsedMm
        self.usedEmbeddedSettings = usedEmbeddedSettings
    }
}

/// État d'un job de découpe interrogé via `GET /slice-jobs/{id}`.
public struct SliceJob: Codable, Sendable, Hashable, Identifiable {
    /// Statut du job tel que renvoyé par le dispatcher (`pending` → `running` → `completed`/
    /// `failed`).
    public enum Status: String, Codable, Sendable, Hashable {
        case pending
        case running
        case completed
        case failed
    }

    public var jobId: Int
    public var status: Status
    public var kind: String?
    public var sourceId: Int?
    public var sourceName: String?
    public var progress: Double?
    public var result: SliceResult?
    public var errorStatus: Int?
    public var errorDetail: String?

    public var id: Int {
        jobId
    }

    public init(
        jobId: Int,
        status: Status,
        kind: String? = nil,
        sourceId: Int? = nil,
        sourceName: String? = nil,
        progress: Double? = nil,
        result: SliceResult? = nil,
        errorStatus: Int? = nil,
        errorDetail: String? = nil
    ) {
        self.jobId = jobId
        self.status = status
        self.kind = kind
        self.sourceId = sourceId
        self.sourceName = sourceName
        self.progress = progress
        self.result = result
        self.errorStatus = errorStatus
        self.errorDetail = errorDetail
    }

    /// `true` quand le job est terminé (succès ou échec) — le polling peut s'arrêter.
    public var isTerminal: Bool {
        status == .completed || status == .failed
    }
}
