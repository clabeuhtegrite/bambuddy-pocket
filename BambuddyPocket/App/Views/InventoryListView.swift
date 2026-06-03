// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import Foundation
import SwiftUI

/// Inventaire des bobines de filament d'un serveur (liste + recherche).
struct InventoryListView: View {
    @State private var model: InventoryListModel
    @State private var query = ""

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeInventoryListModel(for: server))
    }

    private var filtered: [Spool] {
        guard !query.isEmpty else {
            return model.spools
        }
        return model.spools.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
                || ($0.colorName ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { spool in
                NavigationLink {
                    SpoolDetailView(spool: spool)
                } label: {
                    SpoolRow(spool: spool)
                }
            }
        }
        .searchable(text: $query)
        .overlay { placeholder }
        .navigationTitle("Filaments")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.spools.isEmpty {
            ProgressView()
        } else if model.spools.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load filaments", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No spools",
                    systemImage: "circle.dashed",
                    description: Text("No filament in inventory.")
                )
            }
        }
    }
}

private struct SpoolRow: View {
    let spool: Spool

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Circle()
                .fill(PrinterPresentation.color(hexRGBA: spool.rgba) ?? .secondary)
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(.quaternary))
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(spool.displayName)
                    .font(.headline)
                    .lineLimit(1)
                if let color = spool.colorName {
                    Text(color)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let fraction = spool.remainingFraction {
                    ProgressView(value: fraction)
                }
            }
            Spacer()
            if let remaining = spool.remainingGrams {
                Text("\(Int(remaining)) g")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }
}

/// Détail d'une bobine.
struct SpoolDetailView: View {
    let spool: Spool

    var body: some View {
        List {
            Section("Filament") {
                LabeledContent("Material", value: spool.material)
                if let brand = spool.brand {
                    LabeledContent("Brand", value: brand)
                }
                if let color = spool.colorName {
                    LabeledContent("Color") {
                        HStack(spacing: DSSpacing.sm) {
                            Circle()
                                .fill(PrinterPresentation.color(hexRGBA: spool.rgba) ?? .secondary)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().strokeBorder(.quaternary))
                            Text(color)
                        }
                    }
                }
            }
            Section("Weight") {
                if let remaining = spool.remainingGrams {
                    LabeledContent("Remaining", value: "\(Int(remaining)) g")
                }
                if let used = spool.weightUsed {
                    LabeledContent("Used", value: "\(Int(used)) g")
                }
                if let total = spool.labelWeight {
                    LabeledContent("Total", value: "\(total) g")
                }
            }
            storageSection
        }
        .navigationTitle(spool.displayName)
        .toolbarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var storageSection: some View {
        if spool.storageLocation != nil || spool.category != nil || spool.note != nil || spool.costPerKg != nil {
            Section("Storage") {
                if let location = spool.storageLocation {
                    LabeledContent("Location", value: location)
                }
                if let category = spool.category {
                    LabeledContent("Category", value: category)
                }
                if let cost = spool.costPerKg {
                    LabeledContent("Cost per kg", value: cost.formatted())
                }
                if let note = spool.note {
                    LabeledContent("Note", value: note)
                }
            }
        }
    }
}
