// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Canal bidirectionnel de frames texte (abstraction de `URLSessionWebSocketTask`, injectable
/// pour les tests).
public protocol WebSocketChannel: Sendable {
    func send(_ text: String) async throws
    func receiveText() async throws -> String
    func close()
}

/// Fabrique de canaux WebSocket (permet de substituer le transport en test).
public protocol WebSocketConnecting: Sendable {
    func connect(to url: URL, headers: [String: String]) -> any WebSocketChannel
}

/// Client WebSocket de l'API Bambuddy : ouvre la connexion, décode les frames JSON en
/// `WebSocketEvent` et entretient le keepalive (`ping`). La **reconnexion** est gérée par
/// l'appelant (boucle avec back-off) en relançant `events()`.
public struct WebSocketClient: Sendable {
    private let url: URL
    private let headers: [String: String]
    private let connector: any WebSocketConnecting
    private let pingInterval: Duration

    public init(
        url: URL,
        headers: [String: String] = [:],
        connector: any WebSocketConnecting = URLSessionWebSocketConnector(),
        pingInterval: Duration = .seconds(20)
    ) {
        self.url = url
        self.headers = headers
        self.connector = connector
        self.pingInterval = pingInterval
    }

    /// Ouvre la connexion et renvoie le flux d'événements. Le flux se termine (en erreur) si la
    /// connexion tombe ; le fait d'arrêter d'itérer ferme proprement la connexion.
    public func events() -> AsyncThrowingStream<WebSocketEvent, any Error> {
        let channel = connector.connect(to: url, headers: headers)
        let interval = pingInterval
        return AsyncThrowingStream { continuation in
            let receiveTask = Task {
                do {
                    while true {
                        try Task.checkCancellation()
                        let text = try await channel.receiveText()
                        if let event = Self.decode(text) {
                            continuation.yield(event)
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            let pingTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: interval)
                    if Task.isCancelled { break }
                    try? await channel.send(Self.pingMessage)
                }
            }
            continuation.onTermination = { _ in
                receiveTask.cancel()
                pingTask.cancel()
                channel.close()
            }
        }
    }

    private static let pingMessage = #"{"type":"ping"}"#

    static func decode(_ text: String) -> WebSocketEvent? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder.bambuddy().decode(WebSocketEvent.self, from: data)
    }
}

/// Transport de production basé sur `URLSessionWebSocketTask`.
public struct URLSessionWebSocketConnector: WebSocketConnecting {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func connect(to url: URL, headers: [String: String]) -> any WebSocketChannel {
        var request = URLRequest(url: url)
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        let task = session.webSocketTask(with: request)
        task.resume()
        return URLSessionWebSocketChannel(task: task)
    }
}

private final class URLSessionWebSocketChannel: WebSocketChannel, @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(task: URLSessionWebSocketTask) {
        self.task = task
    }

    func send(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func receiveText() async throws -> String {
        switch try await task.receive() {
        case let .string(text):
            text
        case let .data(data):
            String(bytes: data, encoding: .utf8) ?? ""
        @unknown default:
            ""
        }
    }

    func close() {
        task.cancel(with: .goingAway, reason: nil)
    }
}
