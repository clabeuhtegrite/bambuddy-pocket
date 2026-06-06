// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Sauvegarde distante Git : pousse la configuration du serveur (K-profils, profils cloud, réglages,
/// bobines, historique) vers un dépôt **privé** GitHub/GitLab/Gitea/Forgejo. État, configuration,
/// journal et déclenchement manuel.
struct GitHubBackupView: View {
    @State private var model: GitHubBackupModel
    @State private var isEditing = false
    @State private var confirmingDelete = false

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeGitHubBackupModel(for: server))
    }

    /// Le chargement a échoué (403 admin requis, 404 indisponible ou autre erreur) et aucune donnée
    /// n'est disponible : on n'affiche **que** l'état d'erreur — pas de section « Non configuré » ni
    /// de bouton « Configurer » au-dessus d'un échec.
    private var showsLoadFailure: Bool {
        model.status == nil && model
            .config == nil && (model.isForbidden || model.isUnavailable || model.loadError != nil)
    }

    var body: some View {
        List {
            if !showsLoadFailure {
                statusSection
                if let config = model.config {
                    configSection(config)
                    contentSection(config)
                } else if model.hasLoaded {
                    notConfiguredSection
                }
                if !model.logs.isEmpty {
                    logsSection
                }
                if let message = model.actionMessage {
                    Section { Text(message).font(DSFont.caption).foregroundStyle(DSColor.textSecondary) }
                }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Remote backup")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            if !showsLoadFailure {
                ToolbarItem(placement: .primaryAction) {
                    Button(model.config == nil ? "Configure" : "Edit") { isEditing = true }
                }
            }
        }
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
        .sheet(isPresented: $isEditing) {
            GitHubBackupConfigSheet(model: model, editing: model.config)
        }
        .confirmationDialog(
            "Remove backup configuration?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task { await model.deleteConfig() }
            }
        } message: {
            Text("The repository and access token will be removed from the server.")
        }
    }

    private var statusSection: some View {
        Section("Status") {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: model.isConfigured ? "checkmark.icloud" : "icloud.slash")
                    .foregroundStyle(model.isConfigured ? DSColor.statusOK : DSColor.textSecondary)
                    .accessibilityHidden(true)
                Text(model.isConfigured ? "Configured" : "Not configured")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
            if let status = model.status {
                if let last = GitHubBackupPresentation.date(status.lastBackupAt) {
                    LabeledContent("Last backup", value: last)
                }
                if let result = status.lastBackupStatus {
                    LabeledContent("Last result", value: GitHubBackupPresentation.statusLabel(result))
                }
                if let next = GitHubBackupPresentation.date(status.nextScheduledRun) {
                    LabeledContent("Next run", value: next)
                }
            }
        }
    }

    private func configSection(_ config: GitHubBackupConfig) -> some View {
        Section("Repository") {
            LabeledContent("URL", value: config.repositoryUrl)
            LabeledContent("Branch", value: config.branch)
            LabeledContent("Provider", value: config.provider.capitalized)
            LabeledContent("Access token") {
                Text(config.hasToken ? "Stored" : "Missing")
                    .foregroundStyle(config.hasToken ? DSColor.statusOK : DSColor.statusWarning)
            }
            LabeledContent("Backups enabled", value: yesNo(config.enabled))
            if config.scheduleEnabled {
                LabeledContent("Schedule", value: config.scheduleType.capitalized)
            } else {
                LabeledContent("Schedule", value: String(localized: "Manual only"))
            }
        }
    }

    private func contentSection(_ config: GitHubBackupConfig) -> some View {
        Section("Included data") {
            backupFlag("K-profiles", config.backupKprofiles)
            backupFlag("Bambu Cloud profiles", config.backupCloudProfiles)
            backupFlag("App settings", config.backupSettings)
            backupFlag("Spool inventory", config.backupSpools)
            backupFlag("Print history", config.backupArchives)
            Button {
                Task { await model.runNow() }
            } label: {
                HStack {
                    Label("Back up now", systemImage: "arrow.up.circle")
                    Spacer()
                    if model.isRunning {
                        ProgressView()
                    }
                }
            }
            .disabled(model.isRunning || !config.enabled)
            Button("Remove configuration", role: .destructive) {
                confirmingDelete = true
            }
        }
    }

    private var notConfiguredSection: some View {
        Section {
            Text("Remote backup is not configured. Tap Configure to push your server data to a private Git repository.")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
    }

    private var logsSection: some View {
        Section("Recent backups") {
            ForEach(model.logs) { log in
                GitHubBackupLogRow(log: log)
                    .listRowBackground(DSColor.card)
            }
        }
    }

    private func backupFlag(_ title: LocalizedStringKey, _ value: Bool) -> some View {
        HStack {
            Image(systemName: value ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(value ? DSColor.statusOK : DSColor.textSecondary)
                .accessibilityHidden(true)
            Text(title).font(DSFont.body).foregroundStyle(DSColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(value ? Text("Included") : Text("Not included"))
    }

    private func yesNo(_ value: Bool) -> String {
        value ? String(localized: "Yes") : String(localized: "No")
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else {
            CloudLoadFailureView(
                loadFailureTitle: "Couldn’t load remote backup",
                isForbidden: model.isForbidden,
                isUnavailable: model.isUnavailable,
                loadError: showsLoadFailure ? model.loadError : nil
            )
        }
    }
}

private struct GitHubBackupLogRow: View {
    let log: GitHubBackupLog

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                DSStatusBadge(
                    GitHubBackupPresentation.statusLabel(log.status),
                    intent: DSStatusIntent.forRawStatus(log.status)
                )
                Spacer()
                if let date = GitHubBackupPresentation.date(log.completedAt ?? log.startedAt) {
                    Text(date).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                }
            }
            let parts = [
                GitHubBackupPresentation.triggerLabel(log.trigger),
                log.commitSha.map { String(localized: "commit \($0)") },
                log.filesChanged > 0 ? String(localized: "\(log.filesChanged) files") : nil
            ].compactMap(\.self)
            if !parts.isEmpty {
                Text(parts.joined(separator: " · "))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            if let error = log.errorMessage, !error.isEmpty {
                Text(error).font(DSFont.caption).foregroundStyle(DSColor.statusError).lineLimit(2)
            }
        }
        .padding(.vertical, DSSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}
