// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Feuille de configuration de l'intégration Spoolman (`PUT /settings/spoolman`).
struct SpoolmanSettingsSheet: View {
    let model: SpoolmanModel
    let settings: SpoolmanSettings?

    @Environment(\.dismiss) private var dismiss
    @State private var enabled: Bool
    @State private var url: String
    @State private var syncMode: String
    @State private var disableWeightSync: Bool
    @State private var reportPartialUsage: Bool
    @State private var isSaving = false

    private let syncModes = ["auto", "manual"]

    init(model: SpoolmanModel, settings: SpoolmanSettings?) {
        self.model = model
        self.settings = settings
        _enabled = State(initialValue: settings?.isEnabled ?? false)
        _url = State(initialValue: settings?.spoolmanUrl ?? "")
        _syncMode = State(initialValue: settings?.spoolmanSyncMode ?? "auto")
        _disableWeightSync = State(initialValue: settings?.isWeightSyncDisabled ?? false)
        _reportPartialUsage = State(initialValue: settings?.reportsPartialUsage ?? true)
    }

    private var trimmedURL: String {
        url.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !isSaving && (!enabled || !trimmedURL.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Enable Spoolman", isOn: $enabled)
                } footer: {
                    Text("Use a Spoolman server to manage filament inventory instead of the built-in tracker.")
                }
                if enabled {
                    Section("Server") {
                        TextField("http://host:7912", text: $url)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    Section("Synchronization") {
                        Picker("Sync mode", selection: $syncMode) {
                            ForEach(syncModes, id: \.self) { mode in
                                Text(SpoolmanPresentation.syncModeLabel(mode)).tag(mode)
                            }
                        }
                        Toggle("Disable weight sync", isOn: $disableWeightSync)
                        Toggle("Report partial usage", isOn: $reportPartialUsage)
                    }
                }
                if let message = model.actionMessage {
                    Section { Text(message).font(DSFont.caption).foregroundStyle(DSColor.statusError) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle("Spoolman settings")
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
        let update = SpoolmanSettingsUpdate(
            spoolmanEnabled: enabled,
            spoolmanUrl: trimmedURL,
            spoolmanSyncMode: syncMode,
            spoolmanDisableWeightSync: disableWeightSync,
            spoolmanReportPartialUsage: reportPartialUsage
        )
        Task {
            let ok = await model.save(update)
            isSaving = false
            if ok {
                dismiss()
            }
        }
    }
}
