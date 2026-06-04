// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Feuille d'édition d'une bobine : matériau, marque, couleur, poids, coût, stockage, note.
/// Mappe sur `PATCH /inventory/spools/{id}` (`SpoolUpdate`).
struct SpoolEditSheet: View {
    let spool: Spool
    let model: InventoryListModel

    @Environment(\.dismiss) private var dismiss
    @State private var material: String
    @State private var brand: String
    @State private var colorName: String
    @State private var labelWeight: Int
    @State private var costPerKg: Double
    @State private var category: String
    @State private var storageLocation: String
    @State private var note: String

    init(spool: Spool, model: InventoryListModel) {
        self.spool = spool
        self.model = model
        _material = State(initialValue: spool.material)
        _brand = State(initialValue: spool.brand ?? "")
        _colorName = State(initialValue: spool.colorName ?? "")
        _labelWeight = State(initialValue: spool.labelWeight ?? 1000)
        _costPerKg = State(initialValue: spool.costPerKg ?? 0)
        _category = State(initialValue: spool.category ?? "")
        _storageLocation = State(initialValue: spool.storageLocation ?? "")
        _note = State(initialValue: spool.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Filament") {
                    TextField("Material", text: $material)
                    TextField("Brand", text: $brand)
                    TextField("Color", text: $colorName)
                }
                Section("Weight & cost") {
                    Stepper(
                        "Total: \(labelWeight) g",
                        value: $labelWeight,
                        in: 0 ... 10000,
                        step: 50
                    )
                    TextField("Cost per kg", value: $costPerKg, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section("Storage") {
                    TextField("Category", text: $category)
                    TextField("Location", text: $storageLocation)
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2 ... 5)
                }
            }
            .dsListBackground()
            .navigationTitle("Edit spool")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await model.update(spool, with: makeUpdate()) }
                        dismiss()
                    }
                }
            }
        }
    }

    private func makeUpdate() -> SpoolUpdate {
        SpoolUpdate(
            material: material.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.trimmingCharacters(in: .whitespacesAndNewlines),
            colorName: colorName.trimmingCharacters(in: .whitespacesAndNewlines),
            labelWeight: labelWeight,
            costPerKg: costPerKg,
            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
            storageLocation: storageLocation.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note
        )
    }
}
