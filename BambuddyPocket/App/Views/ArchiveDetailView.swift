// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI
import UIKit

/// Détail d'une archive d'impression (lecture seule).
struct ArchiveDetailView: View {
    let archive: Archive
    let model: ArchiveListModel

    @State private var showAdded = false
    @State private var isEditing = false
    @State private var thumbnail: UIImage?
    @State private var timelapse: TimelapseInfo?

    private var fileExtension: String? {
        archive.filename?.split(separator: ".").last.map { $0.lowercased() }
    }

    private var isRenderable: Bool {
        ["stl", "3mf", "gcode"].contains(fileExtension)
    }

    /// Libellé du lien de prévisualisation, adapté au format (parcours G-code vs maillage 3D).
    private var previewLabel: LocalizedStringKey {
        fileExtension == "gcode" ? "View G-code toolpath" : "View 3D model"
    }

    var body: some View {
        List {
            thumbnailSection
            if isRenderable {
                Section {
                    NavigationLink {
                        Model3DScreen(archive: archive, model: model)
                    } label: {
                        Label(previewLabel, systemImage: "cube")
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
            notesSection
            filamentSection
            costSection
            timelapseSection
            timelineSection
            detailsSection
        }
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
        .navigationTitle(archive.displayName)
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
            ArchiveEditSheet(archive: archive, model: model)
        }
        .alert("Added to queue", isPresented: $showAdded) {
            Button("OK", role: .cancel) {}
        }
        .task { await loadMedia() }
    }

    private func loadMedia() async {
        if archive.hasThumbnail, thumbnail == nil, let data = await model.thumbnail(archive) {
            thumbnail = UIImage(data: data)
        }
        if archive.hasTimelapse, timelapse == nil {
            timelapse = await model.timelapseInfo(archive)
        }
    }

    @ViewBuilder
    private var thumbnailSection: some View {
        if let thumbnail {
            Section {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .accessibilityLabel("Print preview")
            }
            .listRowBackground(DSColor.card)
        }
    }

    @ViewBuilder
    private var timelapseSection: some View {
        if let timelapse {
            Section("Timelapse") {
                if let resolution = timelapse.resolution {
                    LabeledContent("Resolution", value: resolution)
                }
                if let duration = timelapse.duration {
                    LabeledContent("Duration", value: "\(Int(duration.rounded())) s")
                }
                if let fps = timelapse.fps {
                    LabeledContent("Frame rate", value: "\(Int(fps.rounded())) fps")
                }
                if let size = timelapse.fileSize {
                    LabeledContent("Size", value: Int64(size).formatted(.byteCount(style: .file)))
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if !archive.tagList.isEmpty || !(archive.notes ?? "").isEmpty || !(archive.externalUrl ?? "").isEmpty {
            Section("Notes") {
                if !archive.tagList.isEmpty {
                    LabeledContent("Tags", value: archive.tagList.joined(separator: ", "))
                }
                if let notes = archive.notes, !notes.isEmpty {
                    Text(notes)
                }
                if let link = archive.externalUrl, !link.isEmpty, let url = URL(string: link) {
                    Link(destination: url) {
                        Label("Open link", systemImage: "link")
                    }
                }
            }
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            LabeledContent("Status") {
                DSStatusBadge(
                    archive.status.capitalized,
                    intent: DSStatusIntent.forRawStatus(archive.status),
                    showsDot: false
                )
            }
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
