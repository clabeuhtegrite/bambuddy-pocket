// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Page d'accueil / tableau de bord du serveur sélectionné (proposition A des maquettes).
///
/// Cette première itération pose l'**en-tête** (nom du serveur, sous-titre imprimantes, badge
/// temps réel, cloche de notifications, retour multi-serveurs) et un aperçu synthétique. Les
/// composants riches (carte hero d'impression, cartes imprimantes compactes, bandeau d'alerte,
/// chips, activité) sont ajoutés dans une brique dédiée.
struct HomeDashboardView: View {
    let model: ServerListModel
    let server: ServerConfiguration
    let onBackToServers: () -> Void
    let onSelectTab: (HomeTab) -> Void

    @State private var printers: PrinterListModel
    @State private var showingNotifications = false

    init(
        model: ServerListModel,
        server: ServerConfiguration,
        onBackToServers: @escaping () -> Void,
        onSelectTab: @escaping (HomeTab) -> Void
    ) {
        self.model = model
        self.server = server
        self.onBackToServers = onBackToServers
        self.onSelectTab = onSelectTab
        _printers = State(initialValue: model.makePrinterListModel(for: server))
    }

    private var notificationCenter: ServerNotificationCenter {
        printers.notificationCenter
    }

    private var printingCount: Int {
        printers.printers.count { printers.status(for: $0)?.isPrinting == true }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                summaryCard
            }
            .padding(DSSpacing.md)
        }
        .background(DSColor.background)
        .navigationTitle(server.label)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onBackToServers()
                } label: {
                    Image(systemName: "rectangle.stack")
                }
                .accessibilityLabel("Servers")
            }
            ToolbarItem(placement: .topBarTrailing) {
                RealtimeHeaderBadge(state: printers.realtimeState)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NotificationsToolbarButton(center: notificationCenter) {
                    showingNotifications = true
                }
            }
        }
        .overlay(alignment: .top) {
            NotificationBanner(center: notificationCenter) {
                showingNotifications = true
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView(center: notificationCenter)
        }
        .refreshable { await printers.load() }
        .task { await printers.run() }
    }

    private var summaryCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                Text(printerSummary)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Button {
                    onSelectTab(.printers)
                } label: {
                    Label("View printers", systemImage: "printer")
                }
                .buttonStyle(.dsSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var printerSummary: String {
        let count = printers.printers.count
        let printersText = String(localized: "\(count) printers")
        guard printingCount > 0 else {
            return printersText
        }
        let printingText = String(localized: "\(printingCount) printing")
        return "\(printersText) · \(printingText)"
    }
}

/// Pastille « En direct » de l'en-tête d'accueil, alignée sur la DA (badge de statut vert).
struct RealtimeHeaderBadge: View {
    let state: RealtimeState

    var body: some View {
        DSStatusBadge(label, intent: intent)
            .accessibilityElement(children: .combine)
    }

    private var intent: DSStatusIntent {
        switch state {
        case .connected, .restMode: .success
        case .connecting, .reconnecting: .warning
        }
    }

    private var label: String {
        switch state {
        case .connected: String(localized: "Live")
        case .connecting: String(localized: "Connecting…")
        case .reconnecting: String(localized: "Reconnecting…")
        case .restMode: String(localized: "Updating…")
        }
    }
}
