// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Client de flux caméra **MJPEG** (`multipart/x-mixed-replace`). Consomme le flux d'octets et
/// émet chaque image JPEG complète (délimitée par les marqueurs SOI `FFD8` / EOI `FFD9`).
/// Les en-têtes auth/Cloudflare sont injectés comme sur les autres surfaces.
public struct CameraStreamClient: Sendable {
    private let url: URL
    private let headers: [String: String]
    private let session: URLSession

    public init(url: URL, headers: [String: String] = [:], session: URLSession = .shared) {
        self.url = url
        self.headers = headers
        self.session = session
    }

    /// Flux des images JPEG. Se termine (en erreur) si la connexion tombe ; arrêter d'itérer
    /// ferme la connexion.
    public func frames() -> AsyncThrowingStream<Data, any Error> {
        let url = url
        let headers = headers
        let session = session
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: url)
                    for (field, value) in headers {
                        request.setValue(value, forHTTPHeaderField: field)
                    }
                    let (bytes, response) = try await session.bytes(for: request)
                    if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
                        throw APIError.http(status: http.statusCode, body: nil)
                    }

                    var buffer = Data()
                    var inFrame = false
                    var previous: UInt8 = 0
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        if previous == 0xFF, byte == 0xD8 {
                            buffer.removeAll(keepingCapacity: true)
                            buffer.append(0xFF)
                            buffer.append(0xD8)
                            inFrame = true
                        } else if inFrame {
                            buffer.append(byte)
                            if previous == 0xFF, byte == 0xD9 {
                                continuation.yield(buffer)
                                inFrame = false
                            }
                        }
                        previous = byte
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
