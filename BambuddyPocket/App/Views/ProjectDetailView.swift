// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Détail d'un projet : progression, description, notes, échéances, édition.
struct ProjectDetailView: View {
    let project: Project
    let model: ProjectListModel

    @State private var isEditing = false
    @State private var detail: Project?

    /// Projet enrichi : la liste fournit la progression, le détail fournit description/notes/tags.
    private var current: Project {
        let listItem = model.projects.first { $0.id == project.id } ?? project
        guard var merged = detail else { return listItem }
        merged.progressPercent = listItem.progressPercent
        return merged
    }

    var body: some View {
        List {
            Section("Overview") {
                LabeledContent("Status") {
                    DSStatusBadge(
                        StatusPresentation.label(current.status),
                        intent: DSStatusIntent.forRawStatus(current.status),
                        showsDot: false
                    )
                }
                if let fraction = current.progressFraction {
                    LabeledContent("Progress") {
                        ProgressView(value: fraction)
                            .tint(DSColor.accent)
                    }
                }
                if let target = current.targetCount {
                    LabeledContent("Target", value: "\(target)")
                }
                if let priority = current.priority {
                    LabeledContent("Priority", value: priority.capitalized)
                }
                if let budget = current.budget {
                    LabeledContent("Budget", value: budget.formatted(.currency(code: "EUR")))
                }
            }
            descriptionSection
            notesSection
            Section {
                NavigationLink {
                    ProjectBOMView(project: project, model: model)
                } label: {
                    Label("Bill of materials", systemImage: "list.bullet.rectangle")
                }
                NavigationLink {
                    ProjectTimelineView(project: project, model: model)
                } label: {
                    Label("Timeline", systemImage: "clock")
                }
            }
        }
        .dsListBackground()
        .navigationTitle(current.name)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            ProjectFormSheet(model: model, editing: current)
        }
        .task {
            if detail == nil {
                detail = await model.detail(for: project)
            }
        }
    }

    @ViewBuilder
    private var descriptionSection: some View {
        if let details = current.details, !details.isEmpty {
            Section("Description") {
                Text(details)
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        let project = current
        if !(project.notes ?? "").isEmpty || !(project.tags ?? "").isEmpty || !(project.url ?? "").isEmpty {
            Section("Notes") {
                if let tags = project.tags, !tags.isEmpty {
                    LabeledContent("Tags", value: tags)
                }
                if let notes = project.notes, !notes.isEmpty {
                    Text(notes)
                }
                if let link = project.url, !link.isEmpty, let url = URL(string: link) {
                    Link(destination: url) {
                        Label("Open link", systemImage: "link")
                    }
                }
            }
        }
    }
}
