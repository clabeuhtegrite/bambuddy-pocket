// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Archives rattachées à un projet : liste, ajout depuis l'archive d'impressions et détachement.
struct ProjectArchivesView: View {
    let project: Project
    let model: ProjectListModel

    @State private var archives: [Archive]?
    @State private var hasLoaded = false
    @State private var adding = false

    var body: some View {
        List {
            ForEach(archives ?? []) { archive in
                ProjectArchiveRow(archive: archive)
                    .listRowBackground(DSColor.card)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await remove(archive) }
                        } label: {
                            Label("Remove", systemImage: "minus.circle")
                        }
                    }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Archives")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: {
                    Label("Add archives", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $adding) {
            AddArchivesSheet(project: project, model: model) {
                await load()
            }
        }
        .refreshable { await load() }
        .task {
            if !hasLoaded {
                await load()
            }
        }
    }

    private func load() async {
        archives = await model.projectArchives(for: project)
        hasLoaded = true
    }

    private func remove(_ archive: Archive) async {
        if await model.removeArchive(from: project, archiveID: archive.id) {
            await load()
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else if archives?.isEmpty ?? true {
            ContentUnavailableView(
                "No archives",
                systemImage: "archivebox",
                description: Text("Attach completed prints to keep this project’s history in one place.")
            )
        }
    }
}

/// Ligne compacte d'une archive (nom + statut) pour la liste/sélecteur d'un projet.
private struct ProjectArchiveRow: View {
    let archive: Archive

    var body: some View {
        HStack {
            Text(archive.displayName)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
            Spacer()
            DSStatusBadge(
                StatusPresentation.label(archive.status),
                intent: DSStatusIntent.forRawStatus(archive.status),
                showsDot: false
            )
        }
        .padding(.vertical, DSSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Sélecteur multiple d'archives à rattacher au projet, paginé depuis l'archive d'impressions.
struct AddArchivesSheet: View {
    let project: Project
    let model: ProjectListModel
    let onSaved: () async -> Void

    private static let pageSize = 50

    @Environment(\.dismiss) private var dismiss
    @State private var archives: [Archive] = []
    @State private var selected: Set<Int> = []
    @State private var hasLoaded = false
    @State private var canLoadMore = true
    @State private var isLoadingMore = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(archives) { archive in
                    Button {
                        toggle(archive.id)
                    } label: {
                        HStack {
                            ProjectArchiveRow(archive: archive)
                            Image(systemName: selected.contains(archive.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(archive.id) ? DSColor.accent : DSColor.textSecondary)
                        }
                    }
                    .listRowBackground(DSColor.card)
                }
                if canLoadMore, hasLoaded {
                    loadMoreRow
                }
            }
            .dsListBackground()
            .overlay { placeholder }
            .navigationTitle("Add archives")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .disabled(selected.isEmpty || isSaving)
                }
            }
            .task {
                if !hasLoaded {
                    await loadFirstPage()
                }
            }
        }
    }

    private var loadMoreRow: some View {
        HStack {
            Spacer()
            if isLoadingMore {
                ProgressView().tint(DSColor.accent)
            } else {
                Button("Load more") { Task { await loadMore() } }
            }
            Spacer()
        }
        .listRowBackground(DSColor.card)
    }

    @ViewBuilder
    private var placeholder: some View {
        if !hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else if archives.isEmpty {
            ContentUnavailableView(
                "No archives",
                systemImage: "archivebox",
                description: Text("There are no prints in the archive to attach yet.")
            )
        }
    }

    private func toggle(_ id: Int) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func loadFirstPage() async {
        if let page = await model.archives(limit: Self.pageSize, offset: 0) {
            archives = page
            canLoadMore = page.count == Self.pageSize
        }
        hasLoaded = true
    }

    private func loadMore() async {
        guard canLoadMore, !isLoadingMore else { return }
        isLoadingMore = true
        if let page = await model.archives(limit: Self.pageSize, offset: archives.count) {
            archives.append(contentsOf: page)
            canLoadMore = page.count == Self.pageSize
        } else {
            canLoadMore = false
        }
        isLoadingMore = false
    }

    private func save() async {
        isSaving = true
        if await model.addArchives(to: project, archiveIDs: Array(selected)) {
            await onSaved()
            dismiss()
        }
        isSaving = false
    }
}
