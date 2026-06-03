// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// File d'attente d'impression d'un serveur (liste ordonnée par position + lots).
struct QueueListView: View {
    @State private var model: QueueListModel
    @State private var editing: QueueItem?

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeQueueListModel(for: server))
    }

    var body: some View {
        List {
            if !model.batches.isEmpty {
                Section("Batches") {
                    ForEach(model.batches) { batch in
                        BatchRow(batch: batch)
                            .swipeActions(edge: .trailing) {
                                if batch.status == "active" {
                                    Button(role: .destructive) {
                                        Task { await model.cancelBatch(batch) }
                                    } label: {
                                        Label("Cancel batch", systemImage: "xmark.circle")
                                    }
                                }
                            }
                    }
                }
            }
            Section("Queue") {
                ForEach(model.items) { item in
                    QueueRow(item: item)
                        .swipeActions(edge: .leading) {
                            leadingActions(for: item)
                        }
                        .swipeActions(edge: .trailing) {
                            trailingActions(for: item)
                        }
                }
                .onMove { source, destination in
                    model.move(from: source, to: destination)
                }
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
        .sheet(item: $editing) { item in
            QueueItemEditSheet(item: item, printers: model.printers, model: model)
        }
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private func leadingActions(for item: QueueItem) -> some View {
        if item.status == "pending" {
            Button {
                Task { await model.start(item) }
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .tint(.green)
            Button {
                editing = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    @ViewBuilder
    private func trailingActions(for item: QueueItem) -> some View {
        Button(role: .destructive) {
            Task { await model.delete(item) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        if item.status == "printing" {
            Button {
                Task { await model.stop(item) }
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .tint(.red)
        } else {
            Button {
                Task { await model.cancel(item) }
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .tint(.orange)
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.items.isEmpty {
            ProgressView()
        } else if model.items.isEmpty, model.batches.isEmpty {
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

/// Ligne de file : position, nom, imprimante cible, planification, statut.
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
                if let scheduled = QueuePresentation.scheduledLabel(item.scheduledTime) {
                    Label(scheduled, systemImage: "calendar.badge.clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: DSSpacing.xs) {
                Text(item.status.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ArchivePresentation.statusColor(item.status))
                if item.manualStart == true {
                    Image(systemName: "hand.tap")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Manual start")
                }
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }
}

/// Ligne de lot : nom, progression (résolus / total), statut.
private struct BatchRow: View {
    let batch: PrintBatch

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text(batch.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(batch.status.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ArchivePresentation.statusColor(batch.status))
            }
            ProgressView(value: Double(batch.resolvedCount), total: Double(max(batch.quantity, 1)))
            Text("\(batch.resolvedCount)/\(batch.quantity) done · \(batch.pendingCount) pending")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
