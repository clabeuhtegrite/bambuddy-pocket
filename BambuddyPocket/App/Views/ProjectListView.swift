// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import Foundation
import SwiftUI

/// Projets d'impression d'un serveur (liste + recherche).
struct ProjectListView: View {
    @State private var model: ProjectListModel
    @State private var query = ""
    @State private var isCreating = false

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
                NavigationLink {
                    ProjectDetailView(project: project, model: model)
                } label: {
                    ProjectRow(project: project)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await model.delete(project) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(DSColor.card)
            }
        }
        .dsListBackground()
        .searchable(text: $query)
        .overlay { placeholder }
        .navigationTitle("Projects")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Label("New project", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isCreating) {
            ProjectFormSheet(model: model)
        }
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
                .tint(DSColor.accent)
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
                    .fill(PrinterPresentation.color(hexRGBA: project.color) ?? DSColor.accent)
                    .frame(width: 10, height: 10)
                Text(project.name)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                DSStatusBadge(
                    StatusPresentation.label(project.status),
                    intent: DSStatusIntent.forRawStatus(project.status),
                    showsDot: false
                )
            }
            if let fraction = project.progressFraction {
                ProgressView(value: fraction)
                    .tint(DSColor.accent)
            }
            if let details = project.details, !details.isEmpty {
                Text(details)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
