// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// File d'attente d'impression d'un serveur (liste ordonnée par position + lots).
struct QueueListView: View {
    @State private var model: QueueListModel
    @State private var editing: QueueItem?
    /// Les lots sont une vue secondaire : repliés par défaut pour ne pas reléguer la file active.
    @State private var batchesExpanded = false
    /// Centre de notifications partagé : porte l'état temps réel de la distribution automatique.
    private let notificationCenter: ServerNotificationCenter

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeQueueListModel(for: server))
        notificationCenter = serverList.notificationCenter(for: server)
    }

    var body: some View {
        List {
            // Ordre logique : ce qui part maintenant (distribution auto) → la file active → son
            // historique → les lots (vue secondaire, repliée par défaut).
            dispatchSection
            if !model.activeItems.isEmpty {
                Section("Queue") {
                    ForEach(model.activeItems) { item in
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
            historySection
            batchesSection
        }
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
        .overlay { placeholder }
        .navigationTitle("Print queue")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            // Le mode édition (réordonnancement) ne concerne que les éléments actifs.
            if !model.activeItems.isEmpty {
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

    /// Historique de la file : éléments terminaux (terminés / échoués / annulés), du plus récent au
    /// plus ancien, avec leur compte — équivalent de la section « Historique » du tableau de bord web.
    /// `GET /queue/` les renvoie déjà ; on les présente à part au lieu de les noyer dans la file.
    @ViewBuilder
    private var historySection: some View {
        let history = model.historyItems
        if !history.isEmpty {
            Section {
                ForEach(history) { item in
                    QueueRow(item: item)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await model.delete(item) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Text("History (\(history.count))")
            }
        }
    }

    /// Lots d'impression : vue secondaire repliable (collapsée par défaut) placée **après** la file
    /// active et l'historique, pour ne pas reléguer la file en bas de l'écran.
    @ViewBuilder
    private var batchesSection: some View {
        if !model.batches.isEmpty {
            Section {
                DisclosureGroup(isExpanded: $batchesExpanded) {
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
                } label: {
                    Text("Batches (\(model.batches.count))")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                }
            }
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

    /// Récapitulatif sous la barre, honnête vis-à-vis du statut.
    ///
    /// - Lot **annulé** : met en avant l'annulation (« X annulés ») et, le cas échéant, la part
    ///   réellement terminée — jamais « 2/2 terminés », qui sous-entendrait une réussite.
    /// - Sinon : « réussis / total » + le restant en attente (comportement nominal).
    private var progressSummary: String {
        if batch.isCancelled {
            if batch.completedCount > 0 {
                return String(
                    localized: "\(batch.cancelledCount) cancelled · \(batch.completedCount)/\(batch.quantity) done",
                    comment: "Batch summary: partially printed then cancelled"
                )
            }
            return String(
                localized: "\(batch.cancelledCount) cancelled",
                comment: "Batch summary: fully cancelled batch"
            )
        }
        return String(
            localized: "\(batch.completedCount)/\(batch.quantity) done · \(batch.pendingCount) pending",
            comment: "Batch summary: completed over total and pending count"
        )
    }

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
            // La barre suit la **fraction réellement aboutie** (réussites), pas le simple « résolu » :
            // un lot annulé n'a rien produit → barre vide, jamais une barre pleine et verte. Le tint
            // suit le statut (annulé = ambre) pour rester cohérent avec le badge.
            ProgressView(value: batch.progressFraction, total: 1)
                .tint(DSStatusIntent.forRawStatus(batch.displayStatus).color)
            Text(progressSummary)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
