// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import SwiftUI

/// Formulaire d'ajout d'une imprimante côté serveur (serial + IP + access code Bambu LAN).
struct AddPrinterView: View {
    let model: PrinterListModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var serial = ""
    @State private var ipAddress = ""
    @State private var accessCode = ""
    @State private var location = ""
    @State private var isSaving = false

    private var canSave: Bool {
        ![name, serial, ipAddress, accessCode].contains { $0.trimmedValue.isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Printer") {
                    TextField("Name", text: $name)
                    TextField("Location", text: $location)
                }
                Section("Bambu LAN") {
                    TextField("Serial number", text: $serial)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("IP address", text: $ipAddress)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                    SecureField("Access code", text: $accessCode)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Add printer")
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
            let create = PrinterCreate(
                name: name.trimmedValue,
                serialNumber: serial.trimmedValue,
                ipAddress: ipAddress.trimmedValue,
                accessCode: accessCode,
                location: location.trimmedValue.isEmpty ? nil : location.trimmedValue
            )
            let success = await model.addPrinter(create)
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
