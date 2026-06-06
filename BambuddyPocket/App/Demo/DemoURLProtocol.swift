// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// `URLProtocol` qui sert des **données de démonstration** déterministes pour les captures
/// marketing App Store (`-uitest-demo`). Il intercepte les requêtes REST de l'app et répond avec
/// des fixtures riches (imprimante en cours d'impression, AMS plein, archives, file, bibliothèque)
/// **sans toucher à aucun backend ni à la moindre imprimante réelle**.
///
/// Le temps réel (WebSocket) n'est pas intercepté : son handshake échoue silencieusement et l'app
/// reste sur l'état REST initial — ce qui suffit pour des captures statiques.
///
/// N'est enregistré que lorsque `-uitest-demo` est passé au lancement (cf. `DemoMode`). Aucun effet
/// en build normal.
final class DemoURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        guard DemoMode.isEnabled else { return false }
        return request.url?.host == "demo.local"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, let client else { return }
        let path = url.path
        let (status, body) = DemoRouter.response(forPath: path, query: url.query)

        let headers = ["Content-Type": DemoRouter.contentType(forPath: path)]
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) ?? HTTPURLResponse()

        client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client.urlProtocol(self, didLoad: body)
        client.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Activation centralisée du mode démo + fabrique de la `URLSession` instrumentée.
enum DemoMode {
    /// `true` quand `-uitest-demo` est passé au lancement (captures marketing uniquement).
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest-demo")
    }

    /// Hôte synthétique du serveur de démo. Toute requête vers cet hôte est servie localement par
    /// `DemoURLProtocol` (jamais de trafic réseau réel).
    static let host = "demo.local"

    /// `URLSession` dont la configuration enregistre `DemoURLProtocol` en tête de chaîne.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DemoURLProtocol.self] + (configuration.protocolClasses ?? [])
        return URLSession(configuration: configuration)
    }
}
