// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Catalogue de filaments de référence : liste consultable (type/marque, coût, températures).
struct FilamentCatalogView: View {
    @State private var model: FilamentCatalogModel
    @State private var query = ""

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeFilamentCatalogModel(for: server))
    }

    private var filtered: [FilamentCatalogEntry] {
        guard !query.isEmpty else {
            return model.entries
        }
        return model.entries.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || ($0.type ?? "").localizedCaseInsensitiveContains(query)
                || ($0.brand ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { entry in
                NavigationLink {
                    FilamentCatalogDetailView(entry: entry)
                } label: {
                    FilamentCatalogRow(entry: entry)
                }
                .listRowBackground(DSColor.card)
            }
        }
        .dsListBackground()
        .searchable(text: $query)
        .overlay { placeholder }
        .navigationTitle("Filament catalog")
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
        if !model.hasLoaded, model.entries.isEmpty {
            ProgressView().tint(DSColor.accent)
        } else if model.entries.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load catalog", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "Empty catalog",
                    systemImage: "books.vertical",
                    description: Text("No reference filaments are defined on this server.")
                )
            }
        }
    }
}

private struct FilamentCatalogRow: View {
    let entry: FilamentCatalogEntry

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Circle()
                .fill(PrinterPresentation.color(hexRGBA: entry.colorHex) ?? .secondary)
                .frame(width: 18, height: 18)
                .overlay(Circle().strokeBorder(.quaternary))
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(entry.name)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer()
            if let cost = entry.costPerKg {
                Text(String(format: "%.0f %@", cost, entry.currency ?? ""))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }

    private var subtitle: String {
        [entry.brand, entry.type].compactMap(\.self).joined(separator: " · ")
    }
}

/// Détail d'une entrée de catalogue : type, marque, coût et températures recommandées.
private struct FilamentCatalogDetailView: View {
    let entry: FilamentCatalogEntry

    var body: some View {
        List {
            Section("Filament") {
                if let type = entry.type {
                    LabeledContent("Material", value: type)
                }
                if let brand = entry.brand {
                    LabeledContent("Brand", value: brand)
                }
                if let cost = entry.costPerKg {
                    LabeledContent("Cost per kg", value: String(format: "%.2f %@", cost, entry.currency ?? ""))
                }
                if let density = entry.density {
                    LabeledContent("Density", value: String(format: "%.2f g/cm³", density))
                }
            }
            if entry.nozzleTempRange != nil || entry.bedTempRange != nil {
                Section("Temperatures") {
                    if let nozzle = entry.nozzleTempRange {
                        LabeledContent("Nozzle", value: nozzle)
                    }
                    if let bed = entry.bedTempRange {
                        LabeledContent("Bed", value: bed)
                    }
                }
            }
        }
        .dsListBackground()
        .navigationTitle(entry.name)
        .toolbarTitleDisplayMode(.inline)
    }
}
