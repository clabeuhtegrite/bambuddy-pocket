// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model du flux de **découpe** (slicing) d'un fichier de bibliothèque non tranché :
///
/// 1. charge les présets unifiés (`GET /slicer/presets`) pour alimenter les menus ;
/// 2. tient les sélections (imprimante / process / filament + plaque) ;
/// 3. met le job en file (`POST /library/files/{id}/slice`) ;
/// 4. **interroge** `GET /slice-jobs/{id}` jusqu'à terminaison (succès/échec) ;
/// 5. expose le résultat (fichier tranché ajouté à la bibliothèque, à imprimer via le flux existant
///    — **jamais d'auto-print** sur l'imprimante réelle).
///
/// Lecture seule jusqu'au tap explicite sur « Trancher » : aucune découpe n'est lancée tant que
/// l'utilisateur n'a pas confirmé.
@MainActor
@Observable
final class SliceJobModel: Identifiable {
    /// Identité stable de la feuille (pour `sheet(item:)`).
    nonisolated let id = UUID()

    /// Phase du flux, pilote l'affichage de la feuille.
    enum Phase: Equatable {
        /// Chargement initial des présets.
        case loadingPresets
        /// Formulaire de sélection prêt (présets chargés).
        case ready
        /// Découpe en cours (job en file/exécution) ; `progress` optionnel (0…1).
        case slicing(progress: Double?)
        /// Découpe terminée avec succès.
        case completed(SliceResult)
        /// Échec (chargement, soumission ou job en erreur).
        case failed(String)
    }

    let fileID: Int
    let fileName: String

    private(set) var phase: Phase = .loadingPresets
    private(set) var presets: UnifiedPresetsResponse?

    var selectedPrinter: UnifiedPreset?
    var selectedProcess: UnifiedPreset?
    var selectedFilament: UnifiedPreset?
    /// Numéro de plaque (`nil` ⇒ plaque 1). Conservé simple : la plaque par défaut couvre le cas
    /// courant d'un modèle mono-plaque.
    var plate: Int?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory
    /// Cadence d'interrogation du job de découpe.
    private static let pollInterval = Duration.seconds(2)
    /// Message affiché quand aucun préset n'est disponible (cloud déconnecté, aucun import local).
    private static let noPresetsMessage = String(
        localized: "No slicer presets are available. Sign in to Bambu Cloud or import presets on the server."
    )

    init(
        fileID: Int,
        fileName: String,
        server: ServerConfiguration,
        connectionFactory: ServerConnectionFactory
    ) {
        self.fileID = fileID
        self.fileName = fileName
        self.server = server
        self.connectionFactory = connectionFactory
    }

    /// `true` quand un préset par emplacement est choisi et qu'aucune découpe n'est en cours.
    var canSlice: Bool {
        guard case .ready = phase else { return false }
        return selectedPrinter != nil && selectedProcess != nil && selectedFilament != nil
    }

    /// Charge les présets unifiés et présélectionne le premier de chaque emplacement.
    func loadPresets() async {
        phase = .loadingPresets
        do {
            let client = try connectionFactory.makeClient(for: server)
            let response = try await client.slicerPresets()
            presets = response
            if response.isEmpty {
                phase = .failed(Self.noPresetsMessage)
                return
            }
            selectedPrinter = selectedPrinter ?? response.allPrinters.first
            selectedProcess = selectedProcess ?? response.allProcesses.first
            selectedFilament = selectedFilament ?? response.allFilaments.first
            phase = .ready
        } catch let error as APIError where isUnavailable(error) {
            // 503 : le sidecar de découpe n'est pas joignable / configuré.
            phase = .failed(String(localized: "The slicer is not available on this server."))
        } catch {
            phase = .failed(ErrorMessage.text(for: error))
        }
    }

    /// Met le job en file puis l'interroge jusqu'à terminaison. Ne lance aucune impression.
    func slice() async {
        guard
            let printer = selectedPrinter,
            let process = selectedProcess,
            let filament = selectedFilament
        else { return }
        phase = .slicing(progress: nil)
        let request = SliceRequest(
            printerPreset: printer.ref,
            processPreset: process.ref,
            filamentPresets: [filament.ref],
            plate: plate,
            export3mf: true
        )
        do {
            let client = try connectionFactory.makeClient(for: server)
            let handle = try await client.sliceLibraryFile(id: fileID, request)
            await pollJob(handle.jobId, client: client)
        } catch {
            phase = .failed(ErrorMessage.text(for: error))
        }
    }

    /// Interroge le job jusqu'à `completed`/`failed`, en relayant la progression.
    private func pollJob(_ jobID: Int, client: RESTClient) async {
        while !Task.isCancelled {
            do {
                let job = try await client.sliceJob(id: jobID)
                phase = .slicing(progress: job.progress)
                switch job.status {
                case .completed:
                    phase = .completed(job.result ?? SliceResult())
                    return
                case .failed:
                    phase = .failed(job.errorDetail ?? String(localized: "Slicing failed."))
                    return
                case .pending, .running, .unknown:
                    // `.unknown` (nouvel état amont) est traité comme non terminal : on continue
                    // d'interroger plutôt que de conclure à tort (décodage tolérant B0).
                    break
                }
            } catch {
                phase = .failed(ErrorMessage.text(for: error))
                return
            }
            try? await Task.sleep(for: Self.pollInterval)
        }
    }

    /// Le sidecar de découpe est-il indisponible (503) ?
    private func isUnavailable(_ error: APIError) -> Bool {
        if case let .http(status, _) = error, status == 503 { return true }
        return false
    }
}
