// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Corbeille de la bibliothèque : restauration ou suppression définitive des fichiers supprimés.
struct LibraryTrashView: View {
    let model: LibraryListModel

    @State private var purging: TrashFile?

    var body: some View {
        List {
            if let trash = model.trash, !trash.items.isEmpty {
                Section {
                    Text("Files are kept \(trash.retentionDays) days before automatic deletion.")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .listRowBackground(DSColor.card)
                }
                ForEach(trash.items) { item in
                    TrashRow(item: item)
                        .swipeActions(edge: .leading) {
                            Button {
                                Task { await model.restore(item) }
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(DSColor.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                purging = item
                            } label: {
                                Label("Delete permanently", systemImage: "trash")
                            }
                        }
                        .listRowBackground(DSColor.card)
                }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Trash")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await model.loadTrash() }
        .task {
            if !model.trashLoaded {
                await model.loadTrash()
            }
        }
        .confirmationDialog(
            "Delete permanently?",
            isPresented: Binding(get: { purging != nil }, set: { if !$0 { purging = nil } }),
            titleVisibility: .visible,
            presenting: purging
        ) { item in
            Button("Delete", role: .destructive) {
                Task { await model.purge(item) }
            }
        } message: { _ in
            Text("This permanently removes the file from the server.")
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.trashLoaded {
            ProgressView().tint(DSColor.accent)
        } else if model.trash?.items.isEmpty ?? true {
            if let error = model.trashError {
                ContentUnavailableView {
                    Label("Couldn’t load the trash", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "Trash is empty",
                    systemImage: "trash",
                    description: Text("No deleted files to restore.")
                )
            }
        }
    }
}

private struct TrashRow: View {
    let item: TrashFile

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(item.filename)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
            HStack(spacing: DSSpacing.md) {
                if let size = item.fileSize {
                    Text(Int64(size).formatted(.byteCount(style: .file)))
                }
                if let folder = item.folderName {
                    Label(folder, systemImage: "folder")
                }
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
