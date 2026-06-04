// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import Foundation
import SwiftUI

/// Bibliothèque de modèles d'un serveur (liste + recherche).
struct LibraryListView: View {
    @State private var model: LibraryListModel
    @State private var query = ""
    @State private var moving: LibraryFile?

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeLibraryListModel(for: server))
    }

    private var isSearching: Bool {
        !query.isEmpty
    }

    /// Quand on cherche : tous les fichiers ; sinon : seulement la racine (les autres sont
    /// accessibles via leur dossier).
    private var listedFiles: [LibraryFile] {
        if isSearching {
            return model.files.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
        }
        return model.files(inFolder: nil)
    }

    var body: some View {
        List {
            if !isSearching, !model.folders.isEmpty {
                Section("Folders") {
                    ForEach(model.folders) { folder in
                        NavigationLink {
                            LibraryFolderView(folder: folder, model: model)
                        } label: {
                            LibraryFolderRow(folder: folder)
                        }
                        .listRowBackground(DSColor.card)
                    }
                }
            }
            Section(isSearching ? "Results" : "Files") {
                ForEach(listedFiles) { file in
                    fileRow(file)
                }
            }
        }
        .dsListBackground()
        .searchable(text: $query)
        .overlay { placeholder }
        .navigationTitle("Library")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    LibraryTrashView(model: model)
                } label: {
                    Label("Trash", systemImage: "trash")
                }
            }
        }
        .sheet(item: $moving) { file in
            LibraryMoveSheet(file: file, model: model)
        }
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    private func fileRow(_ file: LibraryFile) -> some View {
        NavigationLink {
            LibraryFileDetailView(file: file, model: model)
        } label: {
            LibraryRow(file: file)
        }
        .swipeActions(edge: .leading) {
            if file.isSliced {
                Button {
                    Task { await model.enqueue(file) }
                } label: {
                    Label("Add to queue", systemImage: "text.append")
                }
                .tint(DSColor.accent)
            }
            Button { moving = file } label: {
                Label("Move", systemImage: "folder")
            }
            .tint(DSColor.textSecondary)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                Task { await model.delete(file) }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .listRowBackground(DSColor.card)
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.files.isEmpty {
            ProgressView()
                .tint(DSColor.accent)
        } else if model.files.isEmpty, model.folders.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load the library", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No files",
                    systemImage: "folder",
                    description: Text("The library is empty.")
                )
            }
        }
    }
}

private struct LibraryRow: View {
    let file: LibraryFile

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(file.displayName)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
            HStack(spacing: DSSpacing.md) {
                if let type = file.fileType {
                    Text(type.uppercased())
                }
                if let size = file.fileSize {
                    Text(Int64(size).formatted(.byteCount(style: .file)))
                }
                if let count = file.printCount, count > 0 {
                    Label("\(count)", systemImage: "printer")
                }
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
