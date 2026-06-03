// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("ServerURLParser")
struct ServerURLParserTests {
    @Test("Une saisie sans schéma est préfixée en http")
    func defaultsToHTTP() throws {
        let url = try ServerURLParser.normalize("192.168.1.50:8000")
        #expect(url.absoluteString == "http://192.168.1.50:8000")
    }

    @Test("Le schéma https est conservé, sans port superflu")
    func keepsHTTPS() throws {
        let url = try ServerURLParser.normalize("https://demo.example")
        #expect(url.absoluteString == "https://demo.example")
        #expect(url.scheme == "https")
    }

    @Test("Le chemin, la requête et le fragment sont retirés")
    func stripsPathAndQuery() throws {
        let url = try ServerURLParser.normalize("http://host:1/dashboard?tab=2#x")
        #expect(url.absoluteString == "http://host:1")
    }

    @Test("Les identifiants intégrés à l'URL sont retirés")
    func stripsCredentials() throws {
        let url = try ServerURLParser.normalize("http://user:pass@host:8000")
        #expect(url.absoluteString == "http://host:8000")
    }

    @Test("Les espaces de bord sont ignorés")
    func trimsWhitespace() throws {
        let url = try ServerURLParser.normalize("  http://host:8000  ")
        #expect(url.absoluteString == "http://host:8000")
    }

    @Test("Le schéma est normalisé en minuscules")
    func lowercasesScheme() throws {
        let url = try ServerURLParser.normalize("HTTPS://host")
        #expect(url.scheme == "https")
    }

    @Test("Une saisie vide lève .empty")
    func rejectsEmpty() {
        #expect(throws: ServerURLError.empty) {
            try ServerURLParser.normalize("   ")
        }
    }

    @Test("Un schéma non http(s) lève .unsupportedScheme")
    func rejectsUnsupportedScheme() {
        #expect(throws: ServerURLError.unsupportedScheme("ftp")) {
            try ServerURLParser.normalize("ftp://host")
        }
    }

    @Test("Une URL sans hôte lève .invalid")
    func rejectsHostless() {
        #expect(throws: ServerURLError.invalid) {
            try ServerURLParser.normalize("http://")
        }
    }
}
