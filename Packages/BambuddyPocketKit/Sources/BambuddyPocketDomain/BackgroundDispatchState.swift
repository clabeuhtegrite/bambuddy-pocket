// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État de la **distribution automatique en arrière-plan** (`background_dispatch`) diffusé sur le
/// WebSocket. Représente les travaux d'impression envoyés directement à une imprimante connectée
/// (réimpression d'archive / impression d'un fichier de bibliothèque) — en file d'attente, en
/// cours (avec progression de téléversement) ou terminés.
public struct BackgroundDispatchState: Codable, Sendable, Hashable {
    /// Nombre total de travaux dans le lot courant.
    public var total: Int
    /// Travaux distribués en attente de démarrage.
    public var dispatched: Int
    /// Travaux en cours de traitement.
    public var processing: Int
    /// Travaux terminés avec succès dans le lot.
    public var completed: Int
    /// Travaux en échec dans le lot.
    public var failed: Int
    /// Travaux en attente (téléversement non démarré).
    public var dispatchedJobs: [BackgroundDispatchJob]
    /// Travaux actuellement en cours (avec progression).
    public var activeJobs: [BackgroundDispatchJob]

    public init(
        total: Int = 0,
        dispatched: Int = 0,
        processing: Int = 0,
        completed: Int = 0,
        failed: Int = 0,
        dispatchedJobs: [BackgroundDispatchJob] = [],
        activeJobs: [BackgroundDispatchJob] = []
    ) {
        self.total = total
        self.dispatched = dispatched
        self.processing = processing
        self.completed = completed
        self.failed = failed
        self.dispatchedJobs = dispatchedJobs
        self.activeJobs = activeJobs
    }

    /// Une distribution est-elle en cours (au moins un travail actif ou en attente) ?
    public var isActive: Bool {
        processing + dispatched > 0
    }
}

/// Un travail de distribution en arrière-plan (en attente ou actif).
public struct BackgroundDispatchJob: Codable, Sendable, Hashable, Identifiable {
    /// Identifiant du travail de distribution (utilisé pour l'annulation).
    public var jobID: Int
    /// Nature du travail : `reprint_archive` ou `print_library_file`.
    public var kind: String?
    /// Identifiant de la source (archive ou fichier).
    public var sourceID: Int?
    /// Libellé affichable de la source.
    public var sourceName: String?
    /// Imprimante cible.
    public var printerID: Int?
    /// Nom de l'imprimante cible.
    public var printerName: String?
    /// Message d'avancement (travail actif).
    public var message: String?
    /// Octets téléversés (travail actif).
    public var uploadBytes: Int?
    /// Octets totaux à téléverser (travail actif).
    public var uploadTotalBytes: Int?
    /// Progression de téléversement en pourcentage (travail actif).
    public var uploadProgressPct: Double?

    public var id: Int {
        jobID
    }

    public init(
        jobID: Int,
        kind: String? = nil,
        sourceID: Int? = nil,
        sourceName: String? = nil,
        printerID: Int? = nil,
        printerName: String? = nil,
        message: String? = nil,
        uploadBytes: Int? = nil,
        uploadTotalBytes: Int? = nil,
        uploadProgressPct: Double? = nil
    ) {
        self.jobID = jobID
        self.kind = kind
        self.sourceID = sourceID
        self.sourceName = sourceName
        self.printerID = printerID
        self.printerName = printerName
        self.message = message
        self.uploadBytes = uploadBytes
        self.uploadTotalBytes = uploadTotalBytes
        self.uploadProgressPct = uploadProgressPct
    }

    private enum CodingKeys: String, CodingKey {
        case jobID = "jobId"
        case kind
        case sourceID = "sourceId"
        case sourceName
        case printerID = "printerId"
        case printerName
        case message
        case uploadBytes
        case uploadTotalBytes
        case uploadProgressPct
    }
}
