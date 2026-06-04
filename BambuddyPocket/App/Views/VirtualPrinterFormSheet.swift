// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Feuille de création (`POST`) ou d'édition (`PUT`) d'une imprimante virtuelle.
struct VirtualPrinterFormSheet: View {
    let model: VirtualPrintersModel
    let editing: VirtualPrinter?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var modelCode: String
    @State private var mode: String
    @State private var accessCode: String = ""
    @State private var autoDispatch: Bool
    @State private var queueForceColorMatch: Bool
    @State private var enabled: Bool
    @State private var isSaving = false

    private let modes = ["immediate", "review", "print_queue", "proxy"]

    init(model: VirtualPrintersModel, editing: VirtualPrinter?) {
        self.model = model
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "Bambuddy")
        _modelCode = State(initialValue: editing?.model ?? "")
        _mode = State(initialValue: editing?.mode ?? "immediate")
        _autoDispatch = State(initialValue: editing?.autoDispatch ?? true)
        _queueForceColorMatch = State(initialValue: editing?.queueForceColorMatch ?? false)
        _enabled = State(initialValue: editing?.enabled ?? false)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Virtual printer name", text: $name)
                }
                Section("Device") {
                    Picker("Model", selection: $modelCode) {
                        Text("Default").tag("")
                        ForEach(model.sortedModels, id: \.code) { entry in
                            Text(entry.name).tag(entry.code)
                        }
                    }
                    Picker("Mode", selection: $mode) {
                        ForEach(modes, id: \.self) { value in
                            Text(VirtualPrinterPresentation.modeLabel(value)).tag(value)
                        }
                    }
                }
                Section {
                    SecureField(accessCodePlaceholder, text: $accessCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Access code")
                } footer: {
                    Text("An 8-character access code. Leave blank to keep the existing one.")
                }
                Section("Behavior") {
                    Toggle("Auto-dispatch", isOn: $autoDispatch)
                    Toggle("Force color match", isOn: $queueForceColorMatch)
                    if editing != nil {
                        Toggle("Enabled", isOn: $enabled)
                    }
                }
                if let message = model.actionMessage {
                    Section { Text(message).font(DSFont.caption).foregroundStyle(DSColor.statusError) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle(editing == nil ? "New virtual printer" : "Edit virtual printer")
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

    private var accessCodePlaceholder: String {
        if let editing, editing.accessCodeSet {
            String(localized: "Access code set")
        } else {
            String(localized: "Access code")
        }
    }

    private func save() {
        isSaving = true
        let token = accessCode.isEmpty ? nil : accessCode
        let chosenModel = modelCode.isEmpty ? nil : modelCode
        Task {
            let ok: Bool = if let editing {
                await model.update(id: editing.id, VirtualPrinterUpdate(
                    name: trimmedName,
                    enabled: enabled,
                    mode: mode,
                    model: chosenModel,
                    accessCode: token,
                    autoDispatch: autoDispatch,
                    queueForceColorMatch: queueForceColorMatch
                ))
            } else {
                await model.create(VirtualPrinterCreate(
                    name: trimmedName,
                    enabled: false,
                    mode: mode,
                    model: chosenModel,
                    accessCode: token,
                    autoDispatch: autoDispatch,
                    queueForceColorMatch: queueForceColorMatch
                ))
            }
            isSaving = false
            if ok {
                dismiss()
            }
        }
    }
}
