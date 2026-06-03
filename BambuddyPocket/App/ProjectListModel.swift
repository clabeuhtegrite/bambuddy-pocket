// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model des projets d'impression d'un serveur (lecture, REST).
@MainActor
@Observable
final class ProjectListModel {
    private(set) var projects: [Project] = []
    private(set) var hasLoaded = false
    var loadError: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            projects = try await client.projects()
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Récupère le détail d'un projet (champs riches : description, notes, tags…), ou `nil`.
    func detail(for project: Project) async -> Project? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.project(id: project.id)
        } catch {
            return nil
        }
    }

    /// Crée un projet puis recharge la liste. Renvoie `true` au succès.
    func create(_ project: ProjectCreate) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            _ = try await client.createProject(project)
            await load()
            return true
        } catch {
            loadError = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Applique une édition et met à jour l'élément en place (puis recharge pour les stats).
    func update(_ project: Project, with edit: ProjectUpdate) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            _ = try await client.updateProject(id: project.id, edit)
            await load()
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }

    /// Supprime un projet puis le retire de la liste.
    func delete(_ project: Project) async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteProject(id: project.id)
            projects.removeAll { $0.id == project.id }
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
    }
}
