// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Découpeur de flux **MJPEG** (`multipart/x-mixed-replace`) : ingère des **blocs** d'octets et
/// émet chaque image JPEG complète, délimitée par les marqueurs SOI (`FFD8`) / EOI (`FFD9`).
///
/// Le découpage se fait par **recherche de sous-séquence sur `Data`** (`firstRange(of:)`) plutôt
/// qu'octet par octet : sur un flux haute fréquence, scanner des blocs entiers évite des centaines
/// de milliers d'itérations Swift par seconde (une `AsyncBytes` itérée octet par octet est coûteuse).
/// Type valeur testable indépendamment du réseau.
struct MJPEGFrameParser {
    private static let soi = Data([0xFF, 0xD8])
    private static let eoi = Data([0xFF, 0xD9])
    /// Plafond du tampon : un flux corrompu (jamais de marqueur EOI) ne doit pas faire enfler la
    /// mémoire sans fin. Au-delà, on rejette le préfixe antérieur au dernier SOI éventuel.
    private static let maxBufferBytes = 8 * 1024 * 1024

    private var buffer = Data()
    /// Décalage à partir duquel chercher l'EOI : évite de re-scanner depuis le début à chaque bloc
    /// (l'EOI ne peut apparaître qu'après le SOI déjà localisé).
    private var searchFrom = 0

    /// Ingère un bloc d'octets et renvoie les images JPEG **complètes** qu'il permet de clôturer
    /// (souvent zéro ou une, parfois plusieurs si le bloc couvre plus d'une frame).
    mutating func ingest(_ chunk: Data) -> [Data] {
        buffer.append(chunk)
        var frames: [Data] = []
        while let frame = nextFrame() {
            frames.append(frame)
        }
        capBuffer()
        return frames
    }

    /// Extrait la prochaine frame complète du tampon (SOI … EOI), ou `nil` s'il en manque une borne.
    /// Rebase les indices sur `0` du tampon après chaque extraction pour rester simple et sûr.
    private mutating func nextFrame() -> Data? {
        guard let soiRange = buffer.firstRange(of: Self.soi) else {
            // Aucun début de frame : on jette le bruit accumulé (en-têtes multipart, séparateurs).
            buffer.removeAll(keepingCapacity: true)
            searchFrom = 0
            return nil
        }
        // Aligne le tampon sur le début de frame (jette tout préfixe avant le SOI courant).
        if soiRange.lowerBound > buffer.startIndex {
            buffer.removeSubrange(buffer.startIndex ..< soiRange.lowerBound)
            searchFrom = 0
        }
        // Cherche l'EOI **après** le SOI (au moins 2 octets plus loin pour ne pas confondre).
        let eoiSearchStart = max(searchFrom, buffer.startIndex + Self.soi.count)
        guard eoiSearchStart <= buffer.endIndex,
              let eoiRange = buffer.range(of: Self.eoi, in: eoiSearchStart ..< buffer.endIndex)
        else {
            // Frame incomplète : on reprendra la recherche d'EOI ici au prochain bloc.
            searchFrom = max(buffer.startIndex + Self.soi.count, buffer.endIndex - (Self.eoi.count - 1))
            return nil
        }
        let frame = buffer.subdata(in: buffer.startIndex ..< eoiRange.upperBound)
        buffer.removeSubrange(buffer.startIndex ..< eoiRange.upperBound)
        searchFrom = 0
        return frame
    }

    /// Garde-fou mémoire : si le tampon dépasse le plafond sans EOI, on tronque sur le dernier SOI
    /// (ou on vide si aucun), pour ne pas accumuler indéfiniment un flux jamais clôturé.
    private mutating func capBuffer() {
        guard buffer.count > Self.maxBufferBytes else { return }
        if let soiRange = buffer.firstRange(of: Self.soi), soiRange.lowerBound > buffer.startIndex {
            buffer.removeSubrange(buffer.startIndex ..< soiRange.lowerBound)
        } else if buffer.firstRange(of: Self.soi) == nil {
            buffer.removeAll(keepingCapacity: true)
        }
        searchFrom = 0
    }
}

/// Client de flux caméra **MJPEG** (`multipart/x-mixed-replace`). Consomme le flux d'octets par
/// **blocs** et émet chaque image JPEG complète (cf. `MJPEGFrameParser`). Les en-têtes
/// auth/Cloudflare sont injectés comme sur les autres surfaces.
public struct CameraStreamClient: Sendable {
    private let url: URL
    private let headers: [String: String]
    private let session: URLSession
    /// Taille des blocs agrégés avant de lancer le découpage : on bufferise les octets de
    /// `AsyncBytes` puis on scanne le bloc d'un coup, au lieu d'un branchement par octet.
    private static let chunkSize = 16 * 1024

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

                    var parser = MJPEGFrameParser()
                    var chunk = Data()
                    chunk.reserveCapacity(Self.chunkSize)
                    for try await byte in bytes {
                        try Task.checkCancellation()
                        chunk.append(byte)
                        if chunk.count >= Self.chunkSize {
                            for frame in parser.ingest(chunk) {
                                continuation.yield(frame)
                            }
                            chunk.removeAll(keepingCapacity: true)
                        }
                    }
                    if !chunk.isEmpty {
                        for frame in parser.ingest(chunk) {
                            continuation.yield(frame)
                        }
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
