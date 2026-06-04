// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Intégration Spoolman : gestion externe de l'inventaire de bobines. État de connexion, réglages
/// (activation, URL, mode de synchronisation) et actions connecter/déconnecter.
struct SpoolmanView: View {
    @State private var model: SpoolmanModel
    @State private var isEditing = false

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeSpoolmanModel(for: server))
    }

    var body: some View {
        List {
            statusSection
            if let settings = model.settings, model.isEnabled {
                settingsSection(settings)
                actionsSection
            } else if model.hasLoaded {
                notEnabledSection
            }
            if let message = model.actionMessage {
                Section { Text(message).font(DSFont.caption).foregroundStyle(DSColor.textSecondary) }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Spoolman")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Configure") { isEditing = true }
            }
        }
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
        .sheet(isPresented: $isEditing) {
            SpoolmanSettingsSheet(model: model, settings: model.settings)
        }
    }

    private var statusSection: some View {
        Section("Status") {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)
                    .accessibilityHidden(true)
                Text(statusText)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
            if let url = model.status?.url ?? nonEmptyURL {
                LabeledContent("URL", value: url)
            }
        }
    }

    private func settingsSection(_ settings: SpoolmanSettings) -> some View {
        Section("Settings") {
            LabeledContent(
                "Integration",
                value: settings.isEnabled
                    ? String(localized: "Enabled") : String(localized: "Disabled")
            )
            LabeledContent("Sync mode", value: SpoolmanPresentation.syncModeLabel(settings.spoolmanSyncMode))
            LabeledContent(
                "Weight sync",
                value: settings.isWeightSyncDisabled
                    ? String(localized: "Disabled") : String(localized: "Enabled")
            )
            LabeledContent(
                "Report partial usage",
                value: settings.reportsPartialUsage
                    ? String(localized: "Yes") : String(localized: "No")
            )
        }
    }

    private var actionsSection: some View {
        Section {
            if model.isConnected {
                Button(role: .destructive) {
                    Task { await model.disconnect() }
                } label: {
                    actionLabel("Disconnect", systemImage: "bolt.slash")
                }
                .disabled(model.isBusy)
            } else {
                Button {
                    Task { await model.connect() }
                } label: {
                    actionLabel("Connect", systemImage: "bolt")
                }
                .disabled(model.isBusy)
            }
        }
    }

    private var notEnabledSection: some View {
        Section {
            Text("Spoolman is not enabled. Tap Configure to set the server URL and turn on external spool tracking.")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    private func actionLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            if model.isBusy {
                ProgressView()
            }
        }
    }

    private var nonEmptyURL: String? {
        guard let url = model.settings?.spoolmanUrl, !url.isEmpty else {
            return nil
        }
        return url
    }

    /// État composite : connecté > activé non connecté > non configuré.
    private enum Connectivity {
        case connected, enabledNotConnected, notConfigured
    }

    private var connectivity: Connectivity {
        if model.isConnected {
            .connected
        } else if model.isEnabled {
            .enabledNotConnected
        } else {
            .notConfigured
        }
    }

    private var statusIcon: String {
        switch connectivity {
        case .connected: "checkmark.circle.fill"
        case .enabledNotConnected: "exclamationmark.triangle"
        case .notConfigured: "circle.slash"
        }
    }

    private var statusColor: Color {
        switch connectivity {
        case .connected: DSColor.statusOK
        case .enabledNotConnected: DSColor.statusWarning
        case .notConfigured: DSColor.textSecondary
        }
    }

    private var statusText: String {
        switch connectivity {
        case .connected: String(localized: "Connected")
        case .enabledNotConnected: String(localized: "Enabled, not connected")
        case .notConfigured: String(localized: "Not configured")
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else if model.status == nil, model.settings == nil, let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t load Spoolman", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        }
    }
}
