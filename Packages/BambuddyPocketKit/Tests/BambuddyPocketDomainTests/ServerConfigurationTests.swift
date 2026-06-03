// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("ServerConfiguration")
struct ServerConfigurationTests {
    private func makeURL(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    @Test("Dérive ws:// pour une base HTTP (LAN)")
    func derivesWebSocketURLForHTTP() throws {
        let cfg = try ServerConfiguration(label: "LAN", baseURL: makeURL("http://192.168.1.50:8000"))
        #expect(cfg.webSocketURL?.absoluteString == "ws://192.168.1.50:8000/api/v1/ws")
        #expect(cfg.isInsecureTransport)
    }

    @Test("Dérive wss:// pour une base HTTPS (reverse proxy)")
    func derivesWebSocketURLForHTTPS() throws {
        let cfg = try ServerConfiguration(label: "proxy", baseURL: makeURL("https://bambuddy.example.com"))
        #expect(cfg.webSocketURL?.absoluteString == "wss://bambuddy.example.com/api/v1/ws")
        #expect(cfg.isInsecureTransport == false)
    }

    @Test("Gère un sous-chemin de base (reverse proxy avec préfixe)")
    func handlesBasePath() throws {
        let cfg = try ServerConfiguration(label: "sub", baseURL: makeURL("https://host.example.com/bambuddy/"))
        #expect(cfg.webSocketURL?.absoluteString == "wss://host.example.com/bambuddy/api/v1/ws")
    }

    @Test("apiBaseURL ajoute le préfixe /api/v1")
    func buildsAPIBaseURL() throws {
        let cfg = try ServerConfiguration(label: "x", baseURL: makeURL("http://10.0.0.2:8000"))
        #expect(cfg.apiBaseURL.absoluteString == "http://10.0.0.2:8000/api/v1")
    }

    @Test("Encodage/décodage Codable round-trip")
    func codableRoundTrip() throws {
        let original = try ServerConfiguration(
            label: "Atelier",
            baseURL: makeURL("https://printers.example.com"),
            authMethod: .apiKey,
            usesCloudflareAccess: true
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ServerConfiguration.self, from: data)
        #expect(decoded == original)
    }
}
