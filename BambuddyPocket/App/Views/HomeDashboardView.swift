// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Page d'accueil / tableau de bord du serveur sélectionné (proposition A des maquettes).
///
/// En-tête (nom du serveur, sous-titre imprimantes, badge temps réel, cloche de notifications,
/// retour multi-serveurs), carte **hero** d'impression en cours, bandeau d'**alerte conditionnel**,
/// cartes **imprimantes compactes**, **chips** d'actions rapides et **activité récente**.
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

    private var snapshots: [PrinterSnapshot] {
        HomeDashboardPresentation.snapshots(printers: printers.printers) { printers.status(for: $0) }
    }

    var body: some View {
        let snapshots = snapshots
        let hero = HomeDashboardPresentation.heroSnapshot(snapshots)
        let alert = HomeDashboardPresentation.alert(snapshots)

        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                subtitle(snapshots)
                if let hero {
                    HeroPrintCard(snapshot: hero) { action in
                        handle(action, for: hero.printer)
                    }
                }
                if let alert {
                    HomeAlertBanner(alert: alert) { onSelectTab(.printers) }
                }
                printersSection(snapshots)
                quickActionsSection
                recentActivitySection
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

    /// Sous-titre sous le grand titre : nombre d'imprimantes et d'impressions en cours.
    private func subtitle(_ snapshots: [PrinterSnapshot]) -> some View {
        let printing = HomeDashboardPresentation.printingCount(snapshots)
        let text = if printing > 0 {
            "\(String(localized: "\(snapshots.count) printers")) · " +
                String(localized: "\(printing) printing")
        } else {
            String(localized: "\(snapshots.count) printers")
        }
        return Text(text)
            .font(DSFont.callout)
            .foregroundStyle(DSColor.textSecondary)
            .accessibilityLabel(text)
    }

    @ViewBuilder
    private func printersSection(_ snapshots: [PrinterSnapshot]) -> some View {
        if !snapshots.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                SectionHeader("Printers")
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: DSSpacing.sm), GridItem(.flexible())],
                    spacing: DSSpacing.sm
                ) {
                    ForEach(snapshots) { snapshot in
                        Button {
                            onSelectTab(.printers)
                        } label: {
                            CompactPrinterCard(snapshot: snapshot)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            SectionHeader("Quick actions")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.sm) {
                    QuickActionChip(titleKey: "Add to queue", systemImage: "plus") {
                        onSelectTab(.queue)
                    }
                    QuickActionChip(titleKey: "Printers", systemImage: "printer") {
                        onSelectTab(.printers)
                    }
                    QuickActionChip(titleKey: "Library", systemImage: "book") {
                        onSelectTab(.library)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
    }

    @ViewBuilder
    private var recentActivitySection: some View {
        let recent = Array(notificationCenter.notifications.prefix(4))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                SectionHeader("Recent activity")
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { index, note in
                        RecentActivityRow(note: note)
                        if index < recent.count - 1 {
                            DSSeparator()
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.md)
                .dsCardSurface()
            }
        }
    }

    /// Exécute une action de la carte hero (pause/reprise/arrêt) sur l'imprimante concernée.
    private func handle(_ action: HeroPrintCard.Action, for printer: Printer) {
        Task {
            switch action {
            case .pauseOrResume:
                if printers.status(for: printer)?.state == .pause {
                    await printers.resume(printer)
                } else {
                    await printers.pause(printer)
                }
            case .stop:
                await printers.stop(printer)
            }
        }
    }
}

/// En-tête de section uniforme (libellé en capitales atténué, comme sur la maquette).
struct SectionHeader: View {
    let titleKey: LocalizedStringKey

    init(_ titleKey: LocalizedStringKey) {
        self.titleKey = titleKey
    }

    var body: some View {
        Text(titleKey)
            .font(DSFont.captionMedium)
            .textCase(.uppercase)
            .foregroundStyle(DSColor.textMuted)
            .accessibilityAddTraits(.isHeader)
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
