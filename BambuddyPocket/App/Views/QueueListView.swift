// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// File d'attente d'impression d'un serveur (liste ordonnée par position).
struct QueueListView: View {
    @State private var model: QueueListModel

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeQueueListModel(for: server))
    }

    var body: some View {
        List {
            ForEach(model.items) { item in
                QueueRow(item: item)
            }
            .onMove { source, destination in
                model.move(from: source, to: destination)
            }
        }
        .overlay { placeholder }
        .navigationTitle("Print queue")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !model.items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
        }
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.items.isEmpty {
            ProgressView()
        } else if model.items.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load the queue", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "Queue is empty",
                    systemImage: "list.number",
                    description: Text("No prints are queued.")
                )
            }
        }
    }
}

/// Ligne de file : position, nom, imprimante cible, statut.
private struct QueueRow: View {
    let item: QueueItem

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Text("\(item.position)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(item.displayName)
                    .font(.headline)
                    .lineLimit(1)
                if let printer = item.printerName {
                    Text(printer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(item.status.capitalized)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ArchivePresentation.statusColor(item.status))
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
