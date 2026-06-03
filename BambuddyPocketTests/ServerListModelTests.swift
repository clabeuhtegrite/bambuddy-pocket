// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocket
@testable import BambuddyPocketDomain

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
}
