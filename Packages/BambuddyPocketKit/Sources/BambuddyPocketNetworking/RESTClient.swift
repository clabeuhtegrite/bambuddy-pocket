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

    /// Snapshot caméra (`GET /printers/{id}/camera/snapshot`) → données JPEG. Le jeton de flux,
    /// quand il est fourni, est ajouté en `?token=` (requis si l'auth est activée côté serveur).
    public func cameraSnapshot(printerID: Int, token: String? = nil) async throws -> Data {
        try await data(forPath: Self.appendingToken("/printers/\(printerID)/camera/snapshot", token))
    }

    /// Télécharge le fichier d'une archive (`GET /archives/{id}/download`) → données brutes.
    public func downloadArchive(id: Int) async throws -> Data {
        try await data(forPath: "/archives/\(id)/download")
    }

    /// Vignette d'une archive (`GET /archives/{id}/thumbnail`) → données image. Le jeton de flux,
    /// quand il est fourni, est ajouté en `?token=` (requis si l'auth est activée côté serveur).
    public func archiveThumbnail(id: Int, token: String? = nil) async throws -> Data {
        try await data(forPath: Self.appendingToken("/archives/\(id)/thumbnail", token))
    }

    /// Vignette d'une plaque d'une archive (`GET /archives/{id}/plate-thumbnail/{index}`). Jeton
    /// de flux ajouté en `?token=` quand il est fourni (requis si l'auth est activée).
    public func archivePlateThumbnail(id: Int, plateIndex: Int, token: String? = nil) async throws -> Data {
        try await data(forPath: Self.appendingToken("/archives/\(id)/plate-thumbnail/\(plateIndex)", token))
    }

    /// Ajoute un jeton de flux caméra (`?token=`) à un chemin, en l'encodant pour l'URL. Renvoie
    /// le chemin inchangé si le jeton est `nil`.
    static func appendingToken(_ path: String, _ token: String?) -> String {
        guard let token, !token.isEmpty else { return path }
        let encoded = token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? token
        return "\(path)?token=\(encoded)"
    }

    /// Téléverse un fichier dans la bibliothèque (`POST /library/files/`, `multipart/form-data`).
    /// `folderID` (optionnel) cible un dossier ; sinon le fichier est déposé à la racine.
    public func uploadLibraryFile(
        filename: String,
        data: Data,
        folderID: Int? = nil
    ) async throws -> LibraryUploadResult {
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = Self.multipartFileBody(filename: filename, data: data, boundary: boundary)
        var path = "/library/files/"
        if let folderID {
            path += "?folder_id=\(folderID)"
        }
        let request = factory.makeRequest(
            path: path,
            method: .post,
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Réponse non HTTP")
        }
        switch http.statusCode {
        case 200 ..< 300:
            do {
                return try JSONDecoder.bambuddy().decode(LibraryUploadResult.self, from: responseData)
            } catch {
                throw APIError.decoding(String(describing: error))
            }
        case 401, 403:
            throw APIError.unauthorized
        default:
            throw APIError.http(status: http.statusCode, body: String(data: responseData, encoding: .utf8))
        }
    }

    /// Encode un corps `multipart/form-data` contenant un unique champ `file`.
    static func multipartFileBody(filename: String, data: Data, boundary: String) -> Data {
        var body = Data()
        let disposition = "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n"
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data(disposition.utf8))
        body.append(Data("Content-Type: application/octet-stream\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}

/// Réponse vide (pour les endpoints qui ne renvoient pas de corps utile).
public struct EmptyResponse: Decodable, Sendable {
    public init() {}
}
