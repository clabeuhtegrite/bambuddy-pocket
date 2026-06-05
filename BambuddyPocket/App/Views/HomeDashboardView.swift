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
    /// Disposition d'accueil choisie par l'utilisateur, persistée entre les lancements.
    @AppStorage("homeVariant") private var variantRaw = HomeVariant.dashboard.rawValue

    private var variant: HomeVariant {
        HomeVariant(rawValue: variantRaw) ?? .dashboard
    }

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
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                content(snapshots)
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
                variantMenu
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

    /// Contenu de l'accueil selon la disposition choisie (A tableau de bord, B focus, C grille).
    @ViewBuilder
    private func content(_ snapshots: [PrinterSnapshot]) -> some View {
        let hero = HomeDashboardPresentation.heroSnapshot(snapshots)
        let alert = HomeDashboardPresentation.alert(snapshots)
        switch variant {
        case .dashboard:
            subtitle(snapshots)
            if let hero {
                HeroPrintCard(snapshot: hero) { handle($0, for: hero.printer) }
            }
            if let alert {
                HomeAlertBanner(alert: alert) { onSelectTab(.printers) }
            }
            printersSection(snapshots)
            quickActionsSection
            recentActivitySection
        case .focus:
            subtitle(snapshots)
            if let hero {
                HeroPrintCard(snapshot: hero) { handle($0, for: hero.printer) }
            } else {
                idlePlaceholder
            }
            if let alert {
                HomeAlertBanner(alert: alert) { onSelectTab(.printers) }
            }
            quickActionsSection
        case .grid:
            HomeStatStrip(
                printing: HomeDashboardPresentation.printingCount(snapshots),
                ready: HomeDashboardPresentation.readyCount(snapshots),
                alerts: HomeDashboardPresentation.alertCount(snapshots)
            ) { onSelectTab(.printers) }
            if let alert {
                HomeAlertBanner(alert: alert) { onSelectTab(.printers) }
            }
            printersSection(snapshots)
            quickActionsSection
        }
    }

    /// Menu de sélection de la disposition d'accueil (A/B/C), persistée via `@AppStorage`.
    private var variantMenu: some View {
        Menu {
            Picker("Home layout", selection: $variantRaw) {
                ForEach(HomeVariant.allCases) { option in
                    Label(option.label, systemImage: option.systemImage).tag(option.rawValue)
                }
            }
        } label: {
            Image(systemName: "rectangle.3.group")
        }
        .accessibilityLabel("Home layout")
    }

    /// Repère affiché en disposition Focus quand aucune impression n'est en cours.
    private var idlePlaceholder: some View {
        VStack(spacing: DSSpacing.sm) {
            Image(systemName: "printer")
                .font(.largeTitle)
                .foregroundStyle(DSColor.textMuted)
            Text("No active print")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xl)
        .dsCardSurface()
        .accessibilityElement(children: .combine)
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
