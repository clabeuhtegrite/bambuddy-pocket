// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

/// **Décodage tolérant** (B0) des énumérations de découpe : une valeur inconnue (nouvel état/tier
/// amont) retombe sur `.unknown` plutôt que de faire échouer tout le décodage.
@Suite("Slicing — décodage tolérant des enums")
struct SlicingDecodingTests {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder.bambuddy().decode(type, from: Data(json.utf8))
    }

    @Test("SliceJob.Status : valeur connue puis inconnue → .unknown, non terminale")
    func sliceJobStatusFallsBack() throws {
        let known = try decode(SliceJob.self, #"{"job_id":1,"status":"running"}"#)
        #expect(known.status == .running)
        #expect(known.isTerminal == false)

        let unknown = try decode(SliceJob.self, #"{"job_id":2,"status":"paused_by_user"}"#)
        #expect(unknown.status == .unknown)
        // Un statut inconnu n'est pas terminal → le polling continue (ne s'arrête pas par erreur).
        #expect(unknown.isTerminal == false)

        let completed = try decode(SliceJob.self, #"{"job_id":3,"status":"completed"}"#)
        #expect(completed.status == .completed)
        #expect(completed.isTerminal == true)
    }

    @Test("SlicePresetRef.Source : tier inconnu → .unknown")
    func presetSourceFallsBack() throws {
        let known = try decode(SlicePresetRef.self, #"{"source":"cloud","id":"42"}"#)
        #expect(known.source == .cloud)

        let unknown = try decode(SlicePresetRef.self, #"{"source":"community","id":"7"}"#)
        #expect(unknown.source == .unknown)
    }

    @Test("UnifiedPresetsResponse.CloudStatus : statut inconnu → .unknown")
    func cloudStatusFallsBack() throws {
        let known = try decode(UnifiedPresetsResponse.self, #"{"cloud_status":"not_authenticated"}"#)
        #expect(known.cloudStatus == .notAuthenticated)

        let unknown = try decode(UnifiedPresetsResponse.self, #"{"cloud_status":"rate_limited"}"#)
        #expect(unknown.cloudStatus == .unknown)
    }
}
