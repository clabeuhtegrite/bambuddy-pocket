// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Formulaire d'édition d'une imprimante côté serveur (`PATCH /printers/{id}`). Seuls les champs
/// modifiés sont transmis ; le code d'accès laissé vide **préserve** le secret existant.
struct EditPrinterSheet: View {
    let printer: Printer
    let model: PrinterListModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var ipAddress: String
    @State private var modelName: String
    @State private var location: String
    @State private var accessCode = ""
    @State private var autoArchive: Bool
    @State private var isActive: Bool
    @State private var isSaving = false

    init(printer: Printer, model: PrinterListModel) {
        self.printer = printer
        self.model = model
        _name = State(initialValue: printer.name)
        _ipAddress = State(initialValue: printer.ipAddress ?? "")
        _modelName = State(initialValue: printer.model ?? "")
        _location = State(initialValue: printer.location ?? "")
        _autoArchive = State(initialValue: printer.autoArchive ?? true)
        _isActive = State(initialValue: printer.isActive ?? true)
    }

    private var canSave: Bool {
        !name.trimmedValue.isEmpty && !ipAddress.trimmedValue.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Printer") {
                    TextField("Name", text: $name)
                    TextField("Model", text: $modelName)
                        .autocorrectionDisabled()
                    TextField("Location", text: $location)
                }
                Section("Bambu LAN") {
                    TextField("IP address", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                    SecureField("New access code (optional)", text: $accessCode)
                        .autocorrectionDisabled()
                }
                Section {
                    Toggle("Active", isOn: $isActive)
                    Toggle("Auto-archive prints", isOn: $autoArchive)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle("Edit printer")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave || isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        Task {
            let trimmedAccess = accessCode.trimmedValue
            let update = PrinterUpdate(
                name: name.trimmedValue,
                ipAddress: ipAddress.trimmedValue,
                accessCode: trimmedAccess.isEmpty ? nil : trimmedAccess,
                model: modelName.trimmedValue.isEmpty ? nil : modelName.trimmedValue,
                location: location.trimmedValue.isEmpty ? nil : location.trimmedValue,
                isActive: isActive,
                autoArchive: autoArchive
            )
            let success = await model.updatePrinter(id: printer.id, update)
            isSaving = false
            if success {
                dismiss()
            }
        }
    }
}

private extension String {
    var trimmedValue: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
