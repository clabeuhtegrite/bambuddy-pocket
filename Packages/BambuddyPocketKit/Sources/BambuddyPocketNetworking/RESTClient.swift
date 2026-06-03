// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import Foundation

/// Implémentation `URLSession` du contrat `APIClient`.
public actor RESTClient: APIClient {
    private let factory: RequestFactory
    private let session: URLSession

    public init(factory: RequestFactory, session: URLSession = .shared) {
        self.factory = factory
        self.session = session
    }

    public func send<Response: Decodable & Sendable>(
        _ path: String,
        method: HTTPMethod,
        body: Data?
    ) async throws -> Response {
        let request = factory.makeRequest(path: path, method: method, body: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Réponse non HTTP")
        }

        switch http.statusCode {
        case 200 ..< 300:
            if Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response {
                return empty
            }
            do {
                return try JSONDecoder.bambuddy().decode(Response.self, from: data)
            } catch {
                throw APIError.decoding(String(describing: error))
            }
        case 401, 403:
            throw APIError.unauthorized
        default:
            throw APIError.http(status: http.statusCode, body: String(data: data, encoding: .utf8))
        }
    }

    /// Récupère le corps **brut** (non-JSON) d'une ressource : snapshot caméra, vignette, etc.
    public func data(forPath path: String, method: HTTPMethod = .get) async throws -> Data {
        let request = factory.makeRequest(path: path, method: method, body: nil)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Réponse non HTTP")
        }
        switch http.statusCode {
        case 200 ..< 300:
            return data
        case 401, 403:
            throw APIError.unauthorized
        default:
            throw APIError.http(status: http.statusCode, body: nil)
        }
    }

    /// Snapshot caméra (`GET /printers/{id}/camera/snapshot`) → données JPEG.
    public func cameraSnapshot(printerID: Int) async throws -> Data {
        try await data(forPath: "/printers/\(printerID)/camera/snapshot")
    }

    /// Télécharge le fichier d'une archive (`GET /archives/{id}/download`) → données brutes.
    public func downloadArchive(id: Int) async throws -> Data {
        try await data(forPath: "/archives/\(id)/download")
    }
}

/// Réponse vide (pour les endpoints qui ne renvoient pas de corps utile).
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}
