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

    /// Exécute une requête et renvoie le corps + la réponse HTTP, en **uniformisant** les erreurs de
    /// transport (réseau injoignable) et le cas d'une réponse non HTTP. Ne valide **pas** le code de
    /// statut — c'est le rôle de `validate(_:data:includesErrorBody:)`.
    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
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
        return (data, http)
    }

    /// **Validation unique** du code de statut HTTP (factorisée des trois surfaces : JSON, données
    /// brutes, upload). Ne lève rien pour un 2xx ; mappe 401 → `unauthorized`, 403 → `forbidden`
    /// (motif extrait du corps), et tout autre code → `http`. `includesErrorBody` joint le corps au
    /// `http` (utile pour les réponses JSON ; omis pour les téléchargements binaires).
    private static func validate(_ http: HTTPURLResponse, data: Data, includesErrorBody: Bool) throws {
        switch http.statusCode {
        case 200 ..< 300:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden(reason: detail(from: data))
        default:
            let body = includesErrorBody ? String(data: data, encoding: .utf8) : nil
            throw APIError.http(status: http.statusCode, body: body)
        }
    }

    public func send<Response: Decodable & Sendable>(
        _ path: String,
        method: HTTPMethod,
        body: Data?
    ) async throws -> Response {
        let request = factory.makeRequest(path: path, method: method, body: body)
        let (data, http) = try await perform(request)
        try Self.validate(http, data: data, includesErrorBody: true)

        if Response.self == EmptyResponse.self, let empty = EmptyResponse() as? Response {
            return empty
        }
        do {
            return try JSONDecoder.bambuddy().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    /// Extrait le champ `detail` d'un corps d'erreur FastAPI (`{"detail":"…"}`), ou `nil` s'il est
    /// absent ou vide. Sert à journaliser le motif précis d'un `403`/erreur serveur.
    static func detail(from data: Data) -> String? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = object["detail"] as? String,
            !detail.isEmpty
        else { return nil }
        return detail
    }

    /// Récupère le corps **brut** (non-JSON) d'une ressource : snapshot caméra, vignette, etc.
    public func data(forPath path: String, method: HTTPMethod = .get) async throws -> Data {
        let request = factory.makeRequest(path: path, method: method, body: nil)
        let (data, http) = try await perform(request)
        // Téléchargements binaires : on ne joint pas le corps (potentiellement non-texte) à l'erreur.
        try Self.validate(http, data: data, includesErrorBody: false)
        return data
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
        let (responseData, http) = try await perform(request)
        try Self.validate(http, data: responseData, includesErrorBody: true)
        do {
            return try JSONDecoder.bambuddy().decode(LibraryUploadResult.self, from: responseData)
        } catch {
            throw APIError.decoding(String(describing: error))
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
