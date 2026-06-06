// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import Foundation
import SwiftUI

/// Archive d'impressions d'un serveur (liste, lecture seule).
struct ArchiveListView: View {
    @State private var model: ArchiveListModel
    @State private var query = ""
    @State private var editing: Archive?

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeArchiveListModel(for: server))
    }

    var body: some View {
        List {
            ForEach(model.archives) { archive in
                NavigationLink {
                    ArchiveDetailView(archive: archive, model: model)
                } label: {
                    ArchiveRow(archive: archive)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        Task { await model.toggleFavorite(archive) }
                    } label: {
                        Label("Favorite", systemImage: archive.isFavorite == true ? "star.slash" : "star")
                    }
                    .tint(DSColor.statusWarning)
                    Button {
                        editing = archive
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(DSColor.accentDark)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await model.delete(archive) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .listRowBackground(DSColor.card)
            }
            if model.canLoadMore {
                loadMoreRow
            }
        }
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
        .searchable(text: $query)
        .onSubmit(of: .search) {
            Task { await model.search(query) }
        }
        .onChange(of: query) { _, newValue in
            if newValue.isEmpty {
                Task { await model.load() }
            }
        }
        .sheet(item: $editing) { archive in
            ArchiveEditSheet(archive: archive, model: model)
        }
        .overlay { placeholder }
        .navigationTitle("Archives")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    ArchiveStatsView(model: model)
                } label: {
                    Image(systemName: "chart.bar")
                }
                .accessibilityLabel("Statistics")
            }
        }
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    /// Ligne de fin de liste : déclenche automatiquement le chargement de la page suivante à son
    /// apparition (et propose un bouton de repli explicite).
    private var loadMoreRow: some View {
        HStack {
            Spacer()
            if model.isLoadingMore {
                ProgressView().tint(DSColor.accent)
            } else {
                Button("Load more") { Task { await model.loadMore() } }
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.accent)
            }
            Spacer()
        }
        .listRowBackground(DSColor.card)
        .task { await model.loadMore() }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.archives.isEmpty {
            ProgressView()
        } else if model.archives.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load archives", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No archives",
                    systemImage: "tray",
                    description: Text("No print history yet.")
                )
            }
        }
    }
}

/// Ligne d'archive : nom, statut, durée et filament.
private struct ArchiveRow: View {
    let archive: Archive

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            let elapsed = archive.printTimeSeconds ?? archive.actualTimeSeconds
            HStack {
                if archive.isFavorite == true {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(DSColor.statusWarning)
                        .accessibilityLabel("Favorite")
                }
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
            if !archive.tagList.isEmpty {
                Text(archive.tagList.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(DSColor.accent)
                    .lineLimit(1)
            }
            HStack(spacing: DSSpacing.md) {
                if let duration = ArchivePresentation.duration(seconds: elapsed) {
                    Label(duration, systemImage: "clock")
                }
                if let filament = ArchivePresentation.filament(grams: archive.filamentUsedGrams) {
                    Label(filament, systemImage: "scalemass")
                }
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
