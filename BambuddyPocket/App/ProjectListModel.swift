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

    // MARK: Nomenclature (BOM) & chronologie

    /// Nomenclature d'un projet, ou `nil` en cas d'échec.
    func bom(for project: Project) async -> [BOMItem]? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.projectBOM(id: project.id)
        } catch {
            loadError = ErrorMessage.text(for: error)
            return nil
        }
    }

    /// Chronologie d'un projet, ou `nil` en cas d'échec.
    func timeline(for project: Project) async -> [TimelineEvent]? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.projectTimeline(id: project.id)
        } catch {
            loadError = ErrorMessage.text(for: error)
            return nil
        }
    }

    /// Ajoute un élément de nomenclature. Renvoie `true` au succès.
    func addBOMItem(to project: Project, _ item: BOMItemCreate) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.addProjectBOMItem(projectID: project.id, item)
            loadError = nil
            return true
        } catch {
            loadError = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Supprime un élément de nomenclature. Renvoie `true` au succès.
    func deleteBOMItem(from project: Project, itemID: Int) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.deleteProjectBOMItem(projectID: project.id, itemID: itemID)
            loadError = nil
            return true
        } catch {
            loadError = ErrorMessage.text(for: error)
            return false
        }
    }

    // MARK: Archives du projet

    /// Archives rattachées au projet, ou `nil` en cas d'échec.
    func projectArchives(for project: Project) async -> [Archive]? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.projectArchives(id: project.id)
        } catch {
            loadError = ErrorMessage.text(for: error)
            return nil
        }
    }

    /// Charge une page d'archives pour le sélecteur d'« ajout d'archive » ; `nil` en cas d'échec.
    func archives(limit: Int, offset: Int) async -> [Archive]? {
        do {
            let client = try connectionFactory.makeClient(for: server)
            return try await client.archives(limit: limit, offset: offset)
        } catch {
            loadError = ErrorMessage.text(for: error)
            return nil
        }
    }

    /// Rattache des archives existantes au projet puis recharge la liste (stats). Renvoie `true` au succès.
    func addArchives(to project: Project, archiveIDs: [Int]) async -> Bool {
        guard !archiveIDs.isEmpty else { return false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.addArchivesToProject(projectID: project.id, archiveIDs: archiveIDs)
            await load()
            return true
        } catch {
            loadError = ErrorMessage.text(for: error)
            return false
        }
    }

    /// Détache une archive du projet puis recharge la liste (stats). Renvoie `true` au succès.
    func removeArchive(from project: Project, archiveID: Int) async -> Bool {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.removeArchivesFromProject(projectID: project.id, archiveIDs: [archiveID])
            await load()
            return true
        } catch {
            loadError = ErrorMessage.text(for: error)
            return false
        }
    }
}
