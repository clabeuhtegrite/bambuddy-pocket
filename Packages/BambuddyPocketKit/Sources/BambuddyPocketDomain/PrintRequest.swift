// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Options communes d'un lancement d'impression (depuis un fichier de bibliothèque ou une archive).
///
/// Les valeurs par défaut sont alignées sur l'amont (`FilePrintRequest`/`ReprintRequest`) : nivellement
/// de plateau et calibration vibration activés, calibration de débit et inspection de couche désactivées.
/// `amsMapping` laissé `nil` ⇒ le serveur **auto-détecte** la correspondance des bacs depuis le 3MF.
public struct PrintLaunchOptions: Sendable, Hashable {
    /// Numéro de plaque pour un 3MF multi-plaques (`nil` ⇒ auto-détection côté serveur).
    public var plateId: Int?
    /// Nom de plaque éventuel (informatif, transmis au serveur tel quel).
    public var plateName: String?
    /// Correspondance des bacs AMS (`(ams_id * 4) + slot_id`, externe = 254). `nil` ⇒ auto.
    public var amsMapping: [Int]?
    public var bedLevelling: Bool
    public var flowCali: Bool
    public var vibrationCali: Bool
    public var layerInspect: Bool
    public var timelapse: Bool
    public var useAms: Bool

    public init(
        plateId: Int? = nil,
        plateName: String? = nil,
        amsMapping: [Int]? = nil,
        bedLevelling: Bool = true,
        flowCali: Bool = false,
        vibrationCali: Bool = true,
        layerInspect: Bool = false,
        timelapse: Bool = false,
        useAms: Bool = true
    ) {
        self.plateId = plateId
        self.plateName = plateName
        self.amsMapping = amsMapping
        self.bedLevelling = bedLevelling
        self.flowCali = flowCali
        self.vibrationCali = vibrationCali
        self.layerInspect = layerInspect
        self.timelapse = timelapse
        self.useAms = useAms
    }
}

/// Corps d'un lancement d'impression depuis la bibliothèque (`POST /library/files/{id}/print`,
/// `FilePrintRequest`). `printer_id` est passé en **query**, jamais dans le corps. Les champs `nil`
/// sont omis pour laisser le serveur appliquer ses propres défauts / son auto-détection.
public struct FilePrintRequest: Codable, Sendable, Hashable {
    public var plateId: Int?
    public var plateName: String?
    public var amsMapping: [Int]?
    public var bedLevelling: Bool
    public var flowCali: Bool
    public var vibrationCali: Bool
    public var layerInspect: Bool
    public var timelapse: Bool
    public var useAms: Bool
    public var projectId: Int?

    public init(options: PrintLaunchOptions, projectId: Int? = nil) {
        plateId = options.plateId
        plateName = options.plateName
        amsMapping = options.amsMapping
        bedLevelling = options.bedLevelling
        flowCali = options.flowCali
        vibrationCali = options.vibrationCali
        layerInspect = options.layerInspect
        timelapse = options.timelapse
        useAms = options.useAms
        self.projectId = projectId
    }
}

/// Corps d'une réimpression d'archive (`POST /archives/{id}/reprint`, `ReprintRequest`). `printer_id`
/// est passé en **query**. Mêmes options que `FilePrintRequest` sans `project_id`.
public struct ReprintRequest: Codable, Sendable, Hashable {
    public var plateId: Int?
    public var plateName: String?
    public var amsMapping: [Int]?
    public var bedLevelling: Bool
    public var flowCali: Bool
    public var vibrationCali: Bool
    public var layerInspect: Bool
    public var timelapse: Bool
    public var useAms: Bool

    public init(options: PrintLaunchOptions) {
        plateId = options.plateId
        plateName = options.plateName
        amsMapping = options.amsMapping
        bedLevelling = options.bedLevelling
        flowCali = options.flowCali
        vibrationCali = options.vibrationCali
        layerInspect = options.layerInspect
        timelapse = options.timelapse
        useAms = options.useAms
    }
}

/// Réponse de dispatch d'impression (corps JSON renvoyé par `…/print` et `…/reprint`). Le travail
/// réel (send/start) est asynchrone côté serveur ; ce résultat confirme la **mise en file** du
/// dispatch.
public struct PrintDispatchResult: Codable, Sendable, Hashable {
    public var status: String
    public var printerId: Int?
    public var archiveId: Int?
    public var filename: String?
    public var dispatchJobId: Int?
    public var dispatchPosition: Int?

    public init(
        status: String,
        printerId: Int? = nil,
        archiveId: Int? = nil,
        filename: String? = nil,
        dispatchJobId: Int? = nil,
        dispatchPosition: Int? = nil
    ) {
        self.status = status
        self.printerId = printerId
        self.archiveId = archiveId
        self.filename = filename
        self.dispatchJobId = dispatchJobId
        self.dispatchPosition = dispatchPosition
    }
}
