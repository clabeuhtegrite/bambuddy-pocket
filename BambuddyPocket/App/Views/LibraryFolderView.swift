// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Contenu d'un dossier de la bibliothèque : sous-dossiers + fichiers, avec déplacement.
struct LibraryFolderView: View {
    let folder: FolderTreeItem
    let model: LibraryListModel

    @State private var moving: LibraryFile?

    private var files: [LibraryFile] {
        model.files(inFolder: folder.id)
    }

    var body: some View {
        List {
            if !folder.subfolders.isEmpty {
                Section("Folders") {
                    ForEach(folder.subfolders) { subfolder in
                        NavigationLink {
                            LibraryFolderView(folder: subfolder, model: model)
                        } label: {
                            LibraryFolderRow(folder: subfolder)
                        }
                        .listRowBackground(DSColor.card)
                    }
                }
            }
            Section("Files") {
                ForEach(files) { file in
                    NavigationLink {
                        LibraryFileDetailView(file: file, model: model)
                    } label: {
                        LibraryFileSummaryRow(file: file)
                    }
                    .swipeActions(edge: .leading) {
                        Button { moving = file } label: {
                            Label("Move", systemImage: "folder")
                        }
                        .tint(DSColor.accent)
                    }
                    .listRowBackground(DSColor.card)
                }
                if files.isEmpty {
                    folderPlaceholder
                }
            }
        }
        .dsListBackground()
        .navigationTitle(folder.name)
        .toolbarTitleDisplayMode(.inline)
        .sheet(item: $moving) { file in
            LibraryMoveSheet(file: file, model: model)
        }
        .refreshable { await model.loadFolder(folder.id) }
        .task {
            // Le listing racine n'inclut pas le contenu des dossiers : on le récupère ici via
            // `GET /library/files/?folder_id=…` (sinon un dossier non vide s'affiche vide).
            if !model.hasLoadedFolder(folder.id) {
                await model.loadFolder(folder.id)
            }
        }
    }

    /// Distingue « en cours de chargement » de « réellement vide » pour ne plus afficher « vide »
    /// par défaut alors que le contenu n'a pas encore été récupéré.
    @ViewBuilder
    private var folderPlaceholder: some View {
        if model.isLoadingFolder(folder.id) || !model.hasLoadedFolder(folder.id) {
            HStack {
                ProgressView()
                Text("Loading…")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .listRowBackground(DSColor.card)
        } else {
            Text("This folder is empty.")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
                .listRowBackground(DSColor.card)
        }
    }
}

/// Une ligne de dossier (nom + nombre de fichiers).
struct LibraryFolderRow: View {
    let folder: FolderTreeItem

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: folder.isExternal == true ? "externaldrive" : "folder")
                .foregroundStyle(DSColor.accent)
            Text(folder.name)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            if let count = folder.fileCount, count > 0 {
                Text("\(count)")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Résumé compact d'un fichier (réutilisé dans les dossiers).
struct LibraryFileSummaryRow: View {
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
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
