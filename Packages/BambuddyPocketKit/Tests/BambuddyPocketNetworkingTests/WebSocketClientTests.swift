// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BambuddyPocketNetworking

/// Canal de test : restitue des frames scriptées puis « bloque » (jusqu'à annulation).
private final class ScriptedChannel: WebSocketChannel, @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [String]

    init(frames: [String]) {
        self.frames = frames
    }

    func send(_: String) async throws {}

    func receiveText() async throws -> String {
        lock.lock()
        let next = frames.isEmpty ? nil : frames.removeFirst()
        lock.unlock()
        if let next {
            return next
        }
        try await Task.sleep(for: .seconds(60))
        throw CancellationError()
    }

    func close() {}
}

private struct ScriptedConnector: WebSocketConnecting {
    let frames: [String]

    func connect(to _: URL, headers _: [String: String]) -> any WebSocketChannel {
        ScriptedChannel(frames: frames)
    }
}

@Suite("WebSocketClient")
struct WebSocketClientTests {
    @Test("Émet les événements décodés depuis le transport")
    func emitsDecodedEvents() async throws {
        let frames = [
            #"{"type":"printer_status","printer_id":1,"data":{"state":"RUNNING","progress":12}}"#,
            #"{"type":"pong"}"#
        ]
        let url = try #require(URL(string: "ws://host.example.com/api/v1/ws"))
        let client = WebSocketClient(
            url: url,
            connector: ScriptedConnector(frames: frames),
            pingInterval: .seconds(3600)
        )

        var received: [WebSocketEvent] = []
        for try await event in client.events() {
            received.append(event)
            if received.count == frames.count {
                break
            }
        }

        #expect(received.count == 2)
        guard case let .printerStatus(printerID, status) = received[0] else {
            Issue.record("premier événement inattendu : \(received[0])")
            return
        }
        #expect(printerID == 1)
        #expect(status.state == .running)
        #expect(received[1] == .pong)
    }

    @Test("decode() ignore une frame non-JSON")
    func ignoresGarbage() {
        #expect(WebSocketClient.decode("not json") == nil)
    }
}
