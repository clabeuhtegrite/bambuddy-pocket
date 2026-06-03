// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Archive d'impressions d'un serveur (liste, lecture seule).
struct ArchiveListView: View {
    @State private var model: ArchiveListModel

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeArchiveListModel(for: server))
    }

    var body: some View {
        List {
            ForEach(model.archives) { archive in
                NavigationLink {
                    ArchiveDetailView(archive: archive)
                } label: {
                    ArchiveRow(archive: archive)
                }
            }
        }
        .overlay { placeholder }
        .navigationTitle("Print history")
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
                Text(archive.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(archive.status.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ArchivePresentation.statusColor(archive.status))
            }
            HStack(spacing: DSSpacing.md) {
                if let duration = ArchivePresentation.duration(seconds: elapsed) {
                    Label(duration, systemImage: "clock")
                }
                if let filament = ArchivePresentation.filament(grams: archive.filamentUsedGrams) {
                    Label(filament, systemImage: "scalemass")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
