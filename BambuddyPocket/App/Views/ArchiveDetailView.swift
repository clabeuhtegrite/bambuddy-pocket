// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Détail d'une archive d'impression (lecture seule).
struct ArchiveDetailView: View {
    let archive: Archive
    let model: ArchiveListModel

    @State private var showAdded = false

    private var fileExtension: String? {
        archive.filename?.split(separator: ".").last.map { $0.lowercased() }
    }

    private var isRenderable: Bool {
        fileExtension == "stl" || fileExtension == "3mf"
    }

    var body: some View {
        List {
            if isRenderable {
                Section {
                    NavigationLink {
                        Model3DScreen(archive: archive, model: model)
                    } label: {
                        Label("View 3D model", systemImage: "cube")
                    }
                }
            }
            Section {
                Button {
                    Task {
                        if await model.enqueue(archive) {
                            showAdded = true
                        }
                    }
                } label: {
                    Label("Add to queue", systemImage: "text.append")
                }
            }
            summarySection
            filamentSection
            costSection
            timelineSection
            detailsSection
        }
        .navigationTitle(archive.displayName)
        .toolbarTitleDisplayMode(.inline)
        .alert("Added to queue", isPresented: $showAdded) {
            Button("OK", role: .cancel) {}
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            LabeledContent("Status", value: archive.status.capitalized)
            if let value = ArchivePresentation.duration(seconds: archive.printTimeSeconds) {
                LabeledContent("Print time", value: value)
            }
            if let value = ArchivePresentation.duration(seconds: archive.actualTimeSeconds) {
                LabeledContent("Actual time", value: value)
            }
            if let layers = archive.totalLayers {
                LabeledContent("Layers", value: "\(layers)")
            }
        }
    }

    @ViewBuilder
    private var filamentSection: some View {
        if archive.filamentType != nil || archive.filamentUsedGrams != nil {
            Section("Filament") {
                if let type = archive.filamentType {
                    LabeledContent("Type", value: type)
                }
                if let value = ArchivePresentation.filament(grams: archive.filamentUsedGrams) {
                    LabeledContent("Used", value: value)
                }
                if let color = archive.filamentColor, let swatch = PrinterPresentation.color(hexRGBA: color) {
                    LabeledContent("Color") {
                        Circle()
                            .fill(swatch)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().strokeBorder(.quaternary))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var costSection: some View {
        if archive.cost != nil || archive.energyKwh != nil {
            Section("Cost & energy") {
                if let cost = archive.cost {
                    LabeledContent("Cost", value: cost.formatted())
                }
                if let energy = archive.energyKwh {
                    LabeledContent("Energy", value: "\(energy.formatted()) kWh")
                }
            }
        }
    }

    @ViewBuilder
    private var timelineSection: some View {
        if archive.startedAt != nil || archive.completedAt != nil || archive.createdAt != nil {
            Section("Timeline") {
                if let value = ArchivePresentation.date(archive.startedAt) {
                    LabeledContent("Started", value: value)
                }
                if let value = ArchivePresentation.date(archive.completedAt) {
                    LabeledContent("Completed", value: value)
                }
                if let value = ArchivePresentation.date(archive.createdAt) {
                    LabeledContent("Created", value: value)
                }
            }
        }
    }

    @ViewBuilder
    private var detailsSection: some View {
        if archive.designer != nil || (archive.runCount ?? 0) > 0 {
            Section("Details") {
                if let designer = archive.designer {
                    LabeledContent("Designer", value: designer)
                }
                if let runs = archive.runCount, runs > 0 {
                    LabeledContent("Runs", value: "\(runs)")
                }
            }
        }
    }
}
