// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import Foundation
import SwiftUI

/// Projets d'impression d'un serveur (liste + recherche).
struct ProjectListView: View {
    @State private var model: ProjectListModel
    @State private var query = ""

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeProjectListModel(for: server))
    }

    private var filtered: [Project] {
        guard !query.isEmpty else {
            return model.projects
        }
        return model.projects.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            ForEach(filtered) { project in
                ProjectRow(project: project)
            }
        }
        .searchable(text: $query)
        .overlay { placeholder }
        .navigationTitle("Projects")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.projects.isEmpty {
            ProgressView()
        } else if model.projects.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load projects", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No projects",
                    systemImage: "folder.badge.gearshape",
                    description: Text("No projects yet.")
                )
            }
        }
    }
}

private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.sm) {
                Circle()
                    .fill(PrinterPresentation.color(hexRGBA: project.color) ?? .accentColor)
                    .frame(width: 10, height: 10)
                Text(project.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(project.status.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ArchivePresentation.statusColor(project.status))
            }
            if let fraction = project.progressFraction {
                ProgressView(value: fraction)
            }
            if let details = project.details, !details.isEmpty {
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
