// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// File d'attente d'impression d'un serveur (liste ordonnée par position + lots).
struct QueueListView: View {
    @State private var model: QueueListModel
    @State private var editing: QueueItem?
    /// Centre de notifications partagé : porte l'état temps réel de la distribution automatique.
    private let notificationCenter: ServerNotificationCenter

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeQueueListModel(for: server))
        notificationCenter = serverList.notificationCenter(for: server)
    }

    var body: some View {
        List {
            dispatchSection
            if !model.batches.isEmpty {
                Section("Batches") {
                    ForEach(model.batches) { batch in
                        BatchRow(batch: batch)
                            .swipeActions(edge: .trailing) {
                                if batch.displayStatus == "active", !batch.isFullyResolved {
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
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
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
            .tint(DSColor.accent)
            Button {
                editing = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(DSColor.accentDark)
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
            .tint(DSColor.statusError)
        } else {
            Button {
                Task { await model.cancel(item) }
            } label: {
                Label("Cancel", systemImage: "xmark")
            }
            .tint(DSColor.statusWarning)
        }
    }

    @ViewBuilder
    private var dispatchSection: some View {
        if let state = notificationCenter.dispatchState, state.isActive {
            Section("Auto distribution") {
                ForEach(state.activeJobs + state.dispatchedJobs) { job in
                    DispatchRow(job: job, isActive: state.activeJobs.contains(job))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await notificationCenter.cancelDispatchJob(job.jobID) }
                            } label: {
                                Label("Cancel", systemImage: "xmark.circle")
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.items.isEmpty {
            ProgressView()
        } else if model.items.isEmpty, model.batches.isEmpty, notificationCenter.dispatchState == nil {
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
            // La position n'est affichée que pour les éléments encore actifs : un élément terminal
            // garde une position serveur obsolète (souvent « 1 ») qui n'a pas de sens à l'écran.
            Text(item.displayPosition.map(String.init) ?? "")
                .font(.headline.monospacedDigit())
                .foregroundStyle(DSColor.textMuted)
                .frame(minWidth: 24, alignment: .trailing)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(item.displayName)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                if let printer = item.printerName {
                    Text(printer)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                if let scheduled = QueuePresentation.scheduledLabel(item.scheduledTime) {
                    Label(scheduled, systemImage: "calendar.badge.clock")
                        .font(.caption2)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: DSSpacing.xs) {
                DSStatusBadge(
                    item.status.capitalized,
                    intent: DSStatusIntent.forRawStatus(item.status),
                    showsDot: false
                )
                if item.manualStart == true {
                    Image(systemName: "hand.tap")
                        .font(.caption2)
                        .foregroundStyle(DSColor.textSecondary)
                        .accessibilityLabel("Manual start")
                }
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }
}

/// Ligne de distribution automatique : source, imprimante cible, progression de téléversement.
private struct DispatchRow: View {
    let job: BackgroundDispatchJob
    let isActive: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text(job.sourceName ?? String(localized: "Print job", comment: "Dispatch job fallback name"))
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                DSStatusBadge(
                    isActive
                        ? String(localized: "Sending", comment: "Dispatch active state")
                        : String(localized: "Queued", comment: "Dispatch queued state"),
                    intent: isActive ? .accent : .neutral,
                    showsDot: false
                )
            }
            if let printer = job.printerName {
                Label(printer, systemImage: "printer")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            if isActive, let percent = job.uploadProgressPct {
                ProgressView(value: percent, total: 100)
                    .tint(DSColor.accent)
                Text("\(Int(percent.rounded()))%")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            } else if isActive, let message = job.message, !message.isEmpty {
                Text(message)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
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
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                DSStatusBadge(
                    batch.displayStatus.capitalized,
                    intent: DSStatusIntent.forRawStatus(batch.displayStatus),
                    showsDot: false
                )
            }
            ProgressView(value: Double(batch.resolvedCount), total: Double(max(batch.quantity, 1)))
                .tint(DSColor.accent)
            Text("\(batch.resolvedCount)/\(batch.quantity) done · \(batch.pendingCount) pending")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
