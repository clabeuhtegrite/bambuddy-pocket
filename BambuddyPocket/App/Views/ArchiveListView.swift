// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// Archive d'impressions d'un serveur (liste, lecture seule + import d'un fichier vers la
/// bibliothèque).
struct ArchiveListView: View {
    @State private var model: ArchiveListModel
    /// Modèle de bibliothèque, utilisé pour **importer** un fichier (gcode/3mf/STL) depuis l'écran
    /// Archives (retour device A6) : il n'existe pas d'endpoint d'upload « archive », on dépose donc
    /// le fichier dans la bibliothèque via `uploadLibraryFile`.
    @State private var library: LibraryListModel
    @State private var query = ""
    @State private var editing: Archive?
    /// Sélecteur de fichier ouvert ?
    @State private var importing = false
    /// Issue d'un import (alerte) — porte de quoi proposer l'impression au succès.
    @State private var importOutcome: ArchiveImportOutcome?
    /// Feuille d'impression, présentée si l'utilisateur choisit d'imprimer le fichier importé.
    @State private var printModel: PrintDispatchModel?

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeArchiveListModel(for: server))
        _library = State(initialValue: serverList.makeLibraryListModel(for: server))
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
        .sheet(item: $printModel) { printModel in
            PrintSheet(model: printModel)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: ArchiveImport.contentTypes) { result in
            handleImport(result)
        }
        .alert(item: $importOutcome) { outcome in
            importAlert(outcome)
        }
        .overlay { placeholder }
        .navigationTitle("Archives")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    importing = true
                } label: {
                    Label("Import a file", systemImage: "plus")
                }
                .accessibilityLabel("Import a file")
            }
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

    /// Lit le fichier choisi (accès sécurisé), le téléverse dans la bibliothèque, puis présente le
    /// résultat — en proposant d'imprimer au succès (retour device A6).
    private func handleImport(_ result: Result<URL, any Error>) {
        guard case let .success(url) = result else { return }
        let needsAccess = url.startAccessingSecurityScopedResource()
        let data = try? Data(contentsOf: url)
        if needsAccess {
            url.stopAccessingSecurityScopedResource()
        }
        guard let data else {
            importOutcome = .failure
            return
        }
        let filename = url.lastPathComponent
        Task {
            guard let uploaded = await library.upload(filename: filename, data: data, toFolder: nil) else {
                importOutcome = .failure
                return
            }
            importOutcome = uploaded.isDuplicate
                ? .duplicate
                : .uploaded(fileID: uploaded.id, name: uploaded.filename)
        }
    }

    /// Alerte d'issue d'import : un succès propose **Imprimer** (réutilise `PrintSheet`) ou **OK**.
    private func importAlert(_ outcome: ArchiveImportOutcome) -> Alert {
        switch outcome {
        case let .uploaded(fileID, name):
            Alert(
                title: Text("File imported"),
                message: Text("The file was added to your library."),
                primaryButton: .default(Text("Print")) {
                    printModel = library.makePrintDispatchModel(forUploadedFileID: fileID, name: name)
                },
                secondaryButton: .cancel(Text("Done"))
            )
        case .duplicate:
            Alert(
                title: Text("Already in your library"),
                message: Text("This file is already in your library."),
                dismissButton: .default(Text("OK"))
            )
        case .failure:
            Alert(title: Text("Import failed"), dismissButton: .default(Text("OK")))
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

/// Issue d'un import depuis l'écran Archives. Un succès porte l'identité du fichier téléversé pour
/// proposer l'impression (retour device A6).
private enum ArchiveImportOutcome: Identifiable {
    case uploaded(fileID: Int, name: String)
    case duplicate
    case failure

    var id: Int {
        switch self {
        case .uploaded: 0
        case .duplicate: 1
        case .failure: 2
        }
    }
}

/// Types de fichiers acceptés à l'import (3MF / STL / G-code) + un repli générique.
private enum ArchiveImport {
    static var contentTypes: [UTType] {
        var types: [UTType] = [.data]
        for identifier in ["com.prusa3d.3mf", "public.standard-tesselated-geometry-format"] {
            if let type = UTType(identifier) {
                types.insert(type, at: 0)
            }
        }
        return types
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
    }

    /// Libellé VoiceOver combiné : nom, statut, favori, durée et filament en une phrase cohérente.
    private var accessibilityLabel: String {
        var parts: [String] = [archive.displayName, StatusPresentation.label(archive.status)]
        if archive.isFavorite == true {
            parts.append(String(localized: "Favorite"))
        }
        let elapsed = archive.printTimeSeconds ?? archive.actualTimeSeconds
        if let duration = ArchivePresentation.duration(seconds: elapsed) {
            parts.append(duration)
        }
        if let filament = ArchivePresentation.filament(grams: archive.filamentUsedGrams) {
            parts.append(filament)
        }
        return parts.joined(separator: ", ")
    }
}
