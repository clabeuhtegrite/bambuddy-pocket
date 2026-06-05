// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Endpoints de **découpe** (slicing). Le sidecar de découpe (OrcaSlicer API) découpe un modèle
/// source en fichier imprimable ; le résultat atterrit dans la bibliothèque. **Aucun** de ces
/// appels ne lance d'impression : l'impression passe par le flux dédié (`…/print`).
public extension APIClient {
    /// Présets de découpe unifiés (cloud / local / standard) pour la modale de découpe
    /// (`GET /slicer/presets`). Alimente les menus imprimante / process / filament.
    func slicerPresets() async throws -> UnifiedPresetsResponse {
        try await get("/slicer/presets")
    }

    /// Met en file un job de découpe pour un fichier de bibliothèque
    /// (`POST /library/files/{id}/slice`, 202). La découpe tourne en arrière-plan ; on interroge
    /// ensuite `GET /slice-jobs/{job_id}`. Ne lance **aucune** impression.
    func sliceLibraryFile(id: Int, _ request: SliceRequest) async throws -> SliceJobHandle {
        let body = try JSONEncoder.bambuddy().encode(request)
        return try await send("/library/files/\(id)/slice", method: .post, body: body)
    }

    /// État d'un job de découpe (`GET /slice-jobs/{id}`) : statut, progression, résultat ou erreur.
    func sliceJob(id: Int) async throws -> SliceJob {
        try await get("/slice-jobs/\(id)")
    }
}
