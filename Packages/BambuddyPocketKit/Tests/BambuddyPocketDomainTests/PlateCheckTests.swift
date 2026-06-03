// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("PlateCheck")
struct PlateCheckTests {
    @Test("Décode une réponse réelle et calcule la confiance en %")
    func decodesRealResponse() throws {
        let json = #"""
        {"is_empty":true,"confidence":0.0,"difference_percent":0.0,
         "message":"Failed to capture camera frame from any source","has_debug_image":false,
         "needs_calibration":false,"light_warning":false,"reference_count":0,"max_references":5}
        """#
        let data = try #require(json.data(using: .utf8))
        let check = try JSONDecoder.bambuddy().decode(PlateCheck.self, from: data)
        #expect(check.isEmpty == true)
        #expect(check.confidencePercent == 0)
        #expect(check.maxReferences == 5)
        #expect(check.message == "Failed to capture camera frame from any source")
    }

    @Test("confidencePercent borne et arrondit")
    func confidenceBounds() {
        var check = PlateCheck(isEmpty: false, confidence: 0.925)
        #expect(check.confidencePercent == 93)
        check.confidence = 1.5
        #expect(check.confidencePercent == 100)
        check.confidence = -0.2
        #expect(check.confidencePercent == 0)
    }

    @Test("Décode l'état caméra")
    func decodesCameraStatus() throws {
        let json = #"{"active":true,"has_frames":false,"seconds_since_frame":null,"stalled":true}"#
        let data = try #require(json.data(using: .utf8))
        let status = try JSONDecoder.bambuddy().decode(CameraStatus.self, from: data)
        #expect(status.active == true)
        #expect(status.hasFrames == false)
        #expect(status.stalled == true)
    }
}
