// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Nomenclature (BOM) d'un projet : liste des pièces/matériaux avec ajout et suppression.
struct ProjectBOMView: View {
    let project: Project
    let model: ProjectListModel

    @State private var items: [BOMItem]?
    @State private var hasLoaded = false
    @State private var adding = false

    var body: some View {
        List {
            ForEach(items ?? []) { item in
                BOMRow(item: item)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await remove(item) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowBackground(DSColor.card)
            }
            if let items, let total = lineTotal(items) {
                Section {
                    LabeledContent("Estimated total", value: total.formatted(.currency(code: "EUR")))
                        .listRowBackground(DSColor.card)
                }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Bill of materials")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { adding = true } label: {
                    Label("Add item", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $adding) {
            BOMItemSheet(project: project, model: model) {
                await load()
            }
        }
        .refreshable { await load() }
        .task {
            if !hasLoaded {
                await load()
            }
        }
    }

    private func load() async {
        items = await model.bom(for: project)
        hasLoaded = true
    }

    private func remove(_ item: BOMItem) async {
        if await model.deleteBOMItem(from: project, itemID: item.id) {
            await load()
        }
    }

    private func lineTotal(_ items: [BOMItem]) -> Double? {
        let totals = items.compactMap(\.lineTotal)
        return totals.isEmpty ? nil : totals.reduce(0, +)
    }

    @ViewBuilder
    private var placeholder: some View {
        if !hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else if items?.isEmpty ?? true {
            ContentUnavailableView(
                "No items",
                systemImage: "list.bullet.rectangle",
                description: Text("Add parts and materials to track this project’s build.")
            )
        }
    }
}

private struct BOMRow: View {
    let item: BOMItem

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text(item.name)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                Spacer()
                if item.complete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DSColor.statusOK)
                        .accessibilityHidden(true)
                }
            }
            HStack(spacing: DSSpacing.md) {
                if let needed = item.quantityNeeded {
                    Text("Qty \(needed)")
                }
                if let price = item.lineTotal {
                    Text(price.formatted(.currency(code: "EUR")))
                }
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
            if let remarks = item.remarks, !remarks.isEmpty {
                Text(remarks)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }
}

/// Feuille de création d'un élément de nomenclature.
struct BOMItemSheet: View {
    let project: Project
    let model: ProjectListModel
    let onSaved: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = 1
    @State private var unitPrice = ""
    @State private var remarks = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1 ... 999)
                    TextField("Unit price", text: $unitPrice)
                        .keyboardType(.decimalPad)
                    TextField("Remarks", text: $remarks, axis: .vertical)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle("Add item")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        let item = BOMItemCreate(
            name: name.trimmingCharacters(in: .whitespaces),
            quantityNeeded: quantity,
            unitPrice: Double(unitPrice.replacingOccurrences(of: ",", with: ".")),
            remarks: remarks.isEmpty ? nil : remarks
        )
        if await model.addBOMItem(to: project, item) {
            await onSaved()
            dismiss()
        }
        isSaving = false
    }
}
