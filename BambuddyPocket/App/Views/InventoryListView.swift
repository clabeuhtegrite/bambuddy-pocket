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
                    SpoolDetailView(spool: spool, model: model)
                } label: {
                    SpoolRow(spool: spool)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await model.delete(spool) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
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

/// Détail d'une bobine : caractéristiques, poids, stockage, historique de consommation + édition.
struct SpoolDetailView: View {
    let spool: Spool
    let model: InventoryListModel

    @State private var isEditing = false
    @State private var usage: [SpoolUsage] = []
    @State private var hasLoadedUsage = false

    /// Bobine à jour depuis le view-model (reflète les éditions), sinon l'instance passée.
    private var current: Spool {
        model.spools.first { $0.id == spool.id } ?? spool
    }

    var body: some View {
        List {
            Section("Filament") {
                LabeledContent("Material", value: current.material)
                if let brand = current.brand {
                    LabeledContent("Brand", value: brand)
                }
                if let color = current.colorName {
                    LabeledContent("Color") {
                        HStack(spacing: DSSpacing.sm) {
                            Circle()
                                .fill(PrinterPresentation.color(hexRGBA: current.rgba) ?? .secondary)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().strokeBorder(.quaternary))
                            Text(color)
                        }
                    }
                }
            }
            Section("Weight") {
                if let remaining = current.remainingGrams {
                    LabeledContent("Remaining", value: "\(Int(remaining)) g")
                }
                if let used = current.weightUsed {
                    LabeledContent("Used", value: "\(Int(used)) g")
                }
                if let total = current.labelWeight {
                    LabeledContent("Total", value: "\(total) g")
                }
                Button("Reset usage counter") {
                    Task { await model.resetUsage(current) }
                }
            }
            storageSection
            usageSection
        }
        .navigationTitle(current.displayName)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            SpoolEditSheet(spool: current, model: model)
        }
        .task {
            if !hasLoadedUsage {
                usage = await model.usage(for: spool)
                hasLoadedUsage = true
            }
        }
    }

    @ViewBuilder
    private var storageSection: some View {
        let spool = current
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

    @ViewBuilder
    private var usageSection: some View {
        if !usage.isEmpty {
            Section("Usage history") {
                ForEach(usage) { entry in
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        HStack {
                            Text(entry.printName ?? "#\(entry.id)")
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(entry.weightUsed)) g")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        if let date = ArchivePresentation.date(entry.createdAt) {
                            Text(date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, DSSpacing.xs)
                }
            }
        }
    }
}
