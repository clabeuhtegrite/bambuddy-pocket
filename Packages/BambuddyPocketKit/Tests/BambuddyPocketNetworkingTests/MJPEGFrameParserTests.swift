// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketNetworking

@Suite("Découpage MJPEG par blocs")
struct MJPEGFrameParserTests {
    private let soi = Data([0xFF, 0xD8])
    private let eoi = Data([0xFF, 0xD9])

    /// Construit une « image » JPEG factice : SOI + charge utile arbitraire + EOI.
    private func frame(_ payload: [UInt8]) -> Data {
        soi + Data(payload) + eoi
    }

    @Test("Une frame complète dans un seul bloc est émise telle quelle")
    func singleFrameSingleChunk() {
        var parser = MJPEGFrameParser()
        let jpeg = frame([0x01, 0x02, 0x03])
        let frames = parser.ingest(jpeg)
        #expect(frames == [jpeg])
    }

    @Test("Une frame répartie sur plusieurs blocs n'est émise qu'à la réception de l'EOI")
    func frameSplitAcrossChunks() {
        var parser = MJPEGFrameParser()
        let jpeg = frame([0x0A, 0x0B, 0x0C, 0x0D])
        let mid = jpeg.count / 2
        let first = parser.ingest(jpeg.prefix(mid))
        #expect(first.isEmpty)
        let second = parser.ingest(jpeg.suffix(jpeg.count - mid))
        #expect(second == [jpeg])
    }

    @Test("Le marqueur EOI coupé à la frontière de bloc est reconstitué")
    func markerSplitAcrossBoundary() {
        var parser = MJPEGFrameParser()
        // … 0xFF en fin de bloc, 0xD9 au début du suivant : la borne EOI traverse la frontière.
        let head = soi + Data([0x11, 0x22, 0xFF])
        let tail = Data([0xD9])
        #expect(parser.ingest(head).isEmpty)
        let frames = parser.ingest(tail)
        #expect(frames == [soi + Data([0x11, 0x22]) + eoi])
    }

    @Test("Plusieurs frames dans un seul bloc sont toutes émises, dans l'ordre")
    func multipleFramesOneChunk() {
        var parser = MJPEGFrameParser()
        let a = frame([0x01])
        let b = frame([0x02, 0x03])
        let frames = parser.ingest(a + b)
        #expect(frames == [a, b])
    }

    @Test("Le bruit multipart avant le SOI est ignoré")
    func leadingNoiseIsDropped() {
        var parser = MJPEGFrameParser()
        let boundary = Data("--frame\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
        let jpeg = frame([0xAA, 0xBB])
        let frames = parser.ingest(boundary + jpeg)
        #expect(frames == [jpeg])
    }

    @Test("Des données sans EOI n'émettent aucune frame")
    func incompleteFrameYieldsNothing() {
        var parser = MJPEGFrameParser()
        let frames = parser.ingest(soi + Data([0x01, 0x02, 0x03]))
        #expect(frames.isEmpty)
    }

    @Test("Le séparateur multipart entre deux frames est bien ignoré")
    func boundaryBetweenFrames() {
        var parser = MJPEGFrameParser()
        let a = frame([0x01])
        let boundary = Data("\r\n--frame\r\nContent-Type: image/jpeg\r\n\r\n".utf8)
        let b = frame([0x02])
        let frames = parser.ingest(a + boundary + b)
        #expect(frames == [a, b])
    }
}
