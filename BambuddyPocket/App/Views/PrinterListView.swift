// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Liste des imprimantes d'un serveur avec statut **temps réel** (REST initial + WebSocket).
struct PrinterListView: View {
    @State private var model: PrinterListModel
    @State private var showingNotifications = false
    @State private var showingAddPrinter = false

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makePrinterListModel(for: server))
    }

    var body: some View {
        List {
            ForEach(model.printers) { printer in
                NavigationLink {
                    PrinterDetailView(printer: printer, model: model)
                } label: {
                    PrinterRow(printer: printer, status: model.status(for: printer))
                }
                .listRowBackground(DSColor.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
        .overlay { placeholder }
        .navigationTitle(model.serverLabel)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddPrinter = true
                } label: {
                    Label("Add printer", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NotificationsToolbarButton(center: model.notificationCenter) {
                    showingNotifications = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                RealtimeBadge(state: model.realtimeState)
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView(center: model.notificationCenter)
        }
        .sheet(isPresented: $showingAddPrinter) {
            AddPrinterView(model: model)
        }
        .refreshable { await model.load() }
        .task { await model.run() }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.printers.isEmpty {
            ProgressView()
        } else if model.printers.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load printers", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No printers",
                    systemImage: "printer",
                    description: Text("No printers are configured on this server.")
                )
            }
        }
    }
}

/// Pastille d'état de la connexion temps réel.
private struct RealtimeBadge: View {
    let state: RealtimeState

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var color: Color {
        switch state {
        case .connected: DSColor.statusOK
        case .connecting: DSColor.statusWarning
        case .reconnecting: DSColor.statusWarning
        // Le repli REST fournit des données vivantes (rafraîchies) : on signale un état sain.
        case .restMode: DSColor.statusOK
        }
    }

    private var label: LocalizedStringKey {
        switch state {
        case .connected: "Live"
        case .connecting: "Connecting…"
        case .reconnecting: "Reconnecting…"
        case .restMode: "Updating…"
        }
    }
}

/// Ligne imprimante : nom, badge d'état, et progression/temps restant si une impression tourne.
private struct PrinterRow: View {
    let printer: Printer
    let status: PrinterStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text(printer.name)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                StateBadge(state: status?.liveState, connected: status?.connected)
            }
            if let status, status.isPrinting {
                activePrint(status)
            } else if let model = printer.model {
                Text(model)
                    .font(DSFont.callout)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }

    @ViewBuilder
    private func activePrint(_ status: PrinterStatus) -> some View {
        if let fraction = status.progressFraction {
            ProgressView(value: fraction)
                .tint(DSColor.accent)
        }
        HStack(spacing: DSSpacing.sm) {
            if let name = status.subtaskName ?? status.currentPrint {
                Text(name)
                    .font(DSFont.caption)
                    .lineLimit(1)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer()
            if let remaining = PrinterPresentation.remainingTime(minutes: status.remainingTime) {
                Label(remaining, systemImage: "clock")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }
}

/// Badge capsule coloré de l'état (ou « Offline » si l'imprimante est déconnectée).
/// S'appuie sur le composant `DSStatusBadge` de la DA et son mapping sémantique.
struct StateBadge: View {
    let state: PrinterState?
    let connected: Bool?

    var body: some View {
        let offline = connected == false
        let text = offline ? String(localized: "Offline") : PrinterPresentation.stateText(state)
        let intent: DSStatusIntent = offline ? .error : DSStatusIntent.forPrinterState(state)
        DSStatusBadge(text, intent: intent, showsDot: false)
    }
}
