// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import Foundation
import SwiftUI

/// Bibliothèque de modèles d'un serveur (liste + recherche).
struct LibraryListView: View {
    @State private var model: LibraryListModel
    @State private var query = ""

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeLibraryListModel(for: server))
    }

    private var filtered: [LibraryFile] {
        guard !query.isEmpty else {
            return model.files
        }
        return model.files.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            ForEach(filtered) { file in
                LibraryRow(file: file)
            }
        }
        .searchable(text: $query)
        .overlay { placeholder }
        .navigationTitle("Library")
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
        if !model.hasLoaded, model.files.isEmpty {
            ProgressView()
        } else if model.files.isEmpty {
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
                .font(.headline)
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
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
