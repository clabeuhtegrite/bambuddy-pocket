// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Journal d'impression : historique paginé des travaux (succès/échec) indépendant des archives.
/// Recherche côté serveur, pagination à la demande et vidage destructif.
struct PrintLogView: View {
    @State private var model: PrintLogModel
    @State private var searchText = ""
    @State private var confirmingClear = false

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makePrintLogModel(for: server))
    }

    var body: some View {
        List {
            ForEach(model.entries) { entry in
                PrintLogRow(entry: entry)
                    .listRowBackground(DSColor.card)
            }
            if model.canLoadMore {
                loadMoreRow
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Print history")
        .toolbarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: Text("Search by name"))
        .onSubmit(of: .search) { Task { await model.search(searchText) } }
        .onChange(of: searchText) { _, newValue in
            if newValue.isEmpty {
                Task { await model.search("") }
            }
        }
        .toolbar {
            if !model.entries.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button(role: .destructive) {
                        confirmingClear = true
                    } label: {
                        Label("Clear log", systemImage: "trash")
                    }
                }
            }
        }
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
        .confirmationDialog(
            "Clear the print log?",
            isPresented: $confirmingClear,
            titleVisibility: .visible
        ) {
            Button("Clear log", role: .destructive) {
                Task { await model.clear() }
            }
        } message: {
            Text("This removes all log entries. Archives and the queue are not affected.")
        }
    }

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
        if !model.hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else if model.entries.isEmpty, let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t load the print log", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        } else if model.entries.isEmpty {
            ContentUnavailableView {
                Label("No print log entries", systemImage: "doc.text.magnifyingglass")
            } description: {
                Text("Completed and failed prints will appear here.")
            }
        }
    }
}

private struct PrintLogRow: View {
    let entry: PrintLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text(entry.printName ?? String(localized: "Untitled print"))
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                DSStatusBadge(PrintLogPresentation.statusLabel(entry.status), intent: statusIntent)
            }
            metadataLine
            if let reason = entry.failureReason, !reason.isEmpty {
                Text(reason)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.statusError)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DSSpacing.xs)
        .accessibilityElement(children: .combine)
    }

    private var statusIntent: DSStatusIntent {
        DSStatusIntent.forRawStatus(entry.status)
    }

    @ViewBuilder
    private var metadataLine: some View {
        let parts = [
            entry.printerName,
            PrintLogPresentation.date(entry.completedAt ?? entry.createdAt),
            ArchivePresentation.duration(seconds: entry.durationSeconds),
            entry.filamentType,
            ArchivePresentation.filament(grams: entry.filamentUsedGrams)
        ].compactMap(\.self)
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .lineLimit(2)
        }
    }
}
