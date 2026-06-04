// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Feuille de configuration de la sauvegarde distante Git (`POST /github-backup/config`).
///
/// Le **jeton d'accès** est en écriture seule : il n'est jamais relu depuis le serveur (qui ne
/// renvoie que `has_token`) ni conservé sur l'appareil. En édition, le champ reste vide ; le laisser
/// vide conserve le jeton existant côté serveur.
struct GitHubBackupConfigSheet: View {
    let model: GitHubBackupModel
    let editing: GitHubBackupConfig?

    @Environment(\.dismiss) private var dismiss
    @State private var repositoryUrl: String
    @State private var accessToken = ""
    @State private var branch: String
    @State private var provider: String
    @State private var allowInsecureHttp: Bool
    @State private var enabled: Bool
    @State private var scheduleEnabled: Bool
    @State private var scheduleType: String
    @State private var backupKprofiles: Bool
    @State private var backupCloudProfiles: Bool
    @State private var backupSettings: Bool
    @State private var backupSpools: Bool
    @State private var backupArchives: Bool
    @State private var isSaving = false

    private let providers = ["github", "gitlab", "gitea", "forgejo"]
    private let schedules = ["hourly", "daily", "weekly"]

    init(model: GitHubBackupModel, editing: GitHubBackupConfig?) {
        self.model = model
        self.editing = editing
        _repositoryUrl = State(initialValue: editing?.repositoryUrl ?? "")
        _branch = State(initialValue: editing?.branch ?? "main")
        _provider = State(initialValue: editing?.provider ?? "github")
        _allowInsecureHttp = State(initialValue: editing?.allowInsecureHttp ?? false)
        _enabled = State(initialValue: editing?.enabled ?? true)
        _scheduleEnabled = State(initialValue: editing?.scheduleEnabled ?? false)
        _scheduleType = State(initialValue: editing?.scheduleType ?? "daily")
        _backupKprofiles = State(initialValue: editing?.backupKprofiles ?? true)
        _backupCloudProfiles = State(initialValue: editing?.backupCloudProfiles ?? true)
        _backupSettings = State(initialValue: editing?.backupSettings ?? false)
        _backupSpools = State(initialValue: editing?.backupSpools ?? false)
        _backupArchives = State(initialValue: editing?.backupArchives ?? false)
    }

    private var trimmedURL: String {
        repositoryUrl.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedURL.isEmpty && !isSaving && (editing != nil || !accessToken.isEmpty)
    }

    /// Texte d'aide du champ jeton : explication à la création, rappel de conservation en édition.
    private var tokenFooter: LocalizedStringKey {
        editing == nil
            ? "A token with repository write access. Sent to the server, never stored on this device."
            : "Leave blank to keep the current token. A new value replaces it on the server."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Repository") {
                    TextField("https://host/owner/repo", text: $repositoryUrl)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Branch", text: $branch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Provider", selection: $provider) {
                        ForEach(providers, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    Toggle("Allow insecure HTTP", isOn: $allowInsecureHttp)
                }
                Section {
                    SecureField("Access token", text: $accessToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Access token")
                } footer: {
                    Text(tokenFooter)
                }
                Section("Schedule") {
                    Toggle("Backups enabled", isOn: $enabled)
                    Toggle("Scheduled backups", isOn: $scheduleEnabled)
                    if scheduleEnabled {
                        Picker("Frequency", selection: $scheduleType) {
                            ForEach(schedules, id: \.self) { Text($0.capitalized).tag($0) }
                        }
                    }
                }
                Section("Included data") {
                    Toggle("K-profiles", isOn: $backupKprofiles)
                    Toggle("Bambu Cloud profiles", isOn: $backupCloudProfiles)
                    Toggle("App settings", isOn: $backupSettings)
                    Toggle("Spool inventory", isOn: $backupSpools)
                    Toggle("Print history", isOn: $backupArchives)
                }
                if let message = model.actionMessage {
                    Section { Text(message).font(DSFont.caption).foregroundStyle(DSColor.statusError) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle(editing == nil ? "Configure backup" : "Edit backup")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        let token = accessToken.isEmpty ? nil : accessToken
        let cleanBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let ok: Bool = if editing == nil {
                await model.create(GitHubBackupConfigCreate(
                    repositoryUrl: trimmedURL,
                    accessToken: token,
                    branch: cleanBranch,
                    provider: provider,
                    scheduleEnabled: scheduleEnabled,
                    scheduleType: scheduleType,
                    backupKprofiles: backupKprofiles,
                    backupCloudProfiles: backupCloudProfiles,
                    backupSettings: backupSettings,
                    backupSpools: backupSpools,
                    backupArchives: backupArchives,
                    allowInsecureHttp: allowInsecureHttp,
                    enabled: enabled
                ))
            } else {
                await model.update(GitHubBackupConfigUpdate(
                    repositoryUrl: trimmedURL,
                    accessToken: token,
                    branch: cleanBranch,
                    provider: provider,
                    scheduleEnabled: scheduleEnabled,
                    scheduleType: scheduleType,
                    backupKprofiles: backupKprofiles,
                    backupCloudProfiles: backupCloudProfiles,
                    backupSettings: backupSettings,
                    backupSpools: backupSpools,
                    backupArchives: backupArchives,
                    allowInsecureHttp: allowInsecureHttp,
                    enabled: enabled
                ))
            }
            isSaving = false
            if ok {
                dismiss()
            }
        }
    }
}
