// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

@MainActor
@Suite("ServerListModel")
struct ServerListModelTests {
    private func makeURL(_ string: String) throws -> URL {
        try #require(URL(string: string))
    }

    @Test("Charge une liste vide au démarrage")
    func loadsEmpty() {
        let model = ServerListModel(environment: .inMemory())
        model.reload()
        #expect(model.servers.isEmpty)
    }

    @Test("Ajoute un serveur et persiste ses secrets")
    func addsServerWithSecrets() throws {
        let model = ServerListModel(environment: .inMemory())
        let server = try ServerConfiguration(
            label: "Atelier",
            baseURL: makeURL("http://192.168.1.50:8000"),
            authMethod: .apiKey
        )
        try model.save(server, secrets: ServerSecrets(apiKey: "bb_secret"))

        #expect(model.servers.count == 1)
        #expect(model.secrets(for: server).apiKey == "bb_secret")
    }

    @Test("Met à jour un serveur existant sans le dupliquer")
    func updatesExistingServer() throws {
        let model = ServerListModel(environment: .inMemory())
        var server = try ServerConfiguration(label: "Old", baseURL: makeURL("http://host:8000"))
        try model.save(server, secrets: ServerSecrets())

        server.label = "New"
        try model.save(server, secrets: ServerSecrets())

        #expect(model.servers.count == 1)
        #expect(model.servers.first?.label == "New")
    }

    @Test("Supprime un serveur et ses secrets")
    func deletesServer() throws {
        let model = ServerListModel(environment: .inMemory())
        let server = try ServerConfiguration(
            label: "Atelier",
            baseURL: makeURL("http://host:8000"),
            authMethod: .apiKey
        )
        try model.save(server, secrets: ServerSecrets(apiKey: "bb_secret"))
        try model.delete(server)

        #expect(model.servers.isEmpty)
        #expect(model.secrets(for: server).isEmpty)
    }

    @Test("Recharge depuis le store persistant")
    func reloadsFromStore() throws {
        let environment = AppEnvironment.inMemory()
        let model = ServerListModel(environment: environment)
        let server = try ServerConfiguration(label: "Atelier", baseURL: makeURL("http://host:8000"))
        try model.save(server, secrets: ServerSecrets())

        let reloaded = ServerListModel(environment: environment)
        reloaded.reload()
        #expect(reloaded.servers.map(\.id) == [server.id])
    }

    // MARK: - Cycle de vie des centres de notifications (B0)

    /// Un changement **cosmétique** (libellé) ne doit pas invalider le centre en cache : on garde la
    /// même session temps réel (pas de reconnexion inutile).
    @Test("save() : un changement de libellé conserve le centre en cache")
    func saveKeepsCenterOnCosmeticChange() throws {
        let model = ServerListModel(environment: .inMemory())
        var server = try ServerConfiguration(label: "Old", baseURL: makeURL("http://host:8000"))
        try model.save(server, secrets: ServerSecrets())
        let center = model.notificationCenter(for: server)

        server.label = "New"
        try model.save(server, secrets: ServerSecrets())

        #expect(model.notificationCenter(for: server) === center)
    }

    /// Un changement de **connexion** (URL) doit invalider le centre : le suivant est une **nouvelle**
    /// instance, bâtie sur la config fraîche (sinon WebSocket/REST pointent vers l'ancienne URL).
    @Test("save() : un changement d'URL invalide le centre en cache")
    func saveInvalidatesCenterOnURLChange() throws {
        let model = ServerListModel(environment: .inMemory())
        var server = try ServerConfiguration(label: "Atelier", baseURL: makeURL("http://host:8000"))
        try model.save(server, secrets: ServerSecrets())
        let center = model.notificationCenter(for: server)

        server = try ServerConfiguration(id: server.id, label: "Atelier", baseURL: makeURL("http://host:9001"))
        try model.save(server, secrets: ServerSecrets())

        #expect(model.notificationCenter(for: server) !== center)
    }

    /// Un changement de **secrets** (clé d'API) invalide aussi le centre (mauvais en-têtes d'auth).
    @Test("save() : un changement de secret invalide le centre en cache")
    func saveInvalidatesCenterOnSecretChange() throws {
        let model = ServerListModel(environment: .inMemory())
        let server = try ServerConfiguration(
            label: "Atelier",
            baseURL: makeURL("http://host:8000"),
            authMethod: .apiKey
        )
        try model.save(server, secrets: ServerSecrets(apiKey: "bb_one"))
        let center = model.notificationCenter(for: server)

        try model.save(server, secrets: ServerSecrets(apiKey: "bb_two"))

        #expect(model.notificationCenter(for: server) !== center)
    }

    /// `stopUnselectedCenters(keeping:)` libère les centres des serveurs non sélectionnés (anti-fuite
    /// multi-serveurs) et conserve celui du serveur affiché.
    @Test("stopUnselectedCenters : ne garde que le serveur sélectionné")
    func stopsUnselectedCenters() throws {
        let model = ServerListModel(environment: .inMemory())
        let a = try ServerConfiguration(label: "A", baseURL: makeURL("http://a:8000"))
        let b = try ServerConfiguration(label: "B", baseURL: makeURL("http://b:8000"))
        try model.save(a, secrets: ServerSecrets())
        try model.save(b, secrets: ServerSecrets())
        let centerA = model.notificationCenter(for: a)
        _ = model.notificationCenter(for: b)

        model.stopUnselectedCenters(keeping: a.id)

        // A reste la même instance (conservée) ; B a été libéré → nouvelle instance au prochain accès.
        #expect(model.notificationCenter(for: a) === centerA)
    }
}
