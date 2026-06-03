// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import SwiftUI

/// Feuille de sélection des routines de calibration à lancer.
struct CalibrationSheet: View {
    let printer: Printer
    let model: PrinterListModel

    @Environment(\.dismiss) private var dismiss
    @State private var bedLeveling = true
    @State private var vibration = false
    @State private var motorNoise = false
    @State private var nozzleOffset = false
    @State private var highTempHeatbed = false

    private var options: CalibrationOptions {
        CalibrationOptions(
            bedLeveling: bedLeveling,
            vibration: vibration,
            motorNoise: motorNoise,
            nozzleOffset: nozzleOffset,
            highTempHeatbed: highTempHeatbed
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Bed leveling", isOn: $bedLeveling)
                    Toggle("Vibration compensation", isOn: $vibration)
                    Toggle("Motor noise cancellation", isOn: $motorNoise)
                    Toggle("Nozzle offset", isOn: $nozzleOffset)
                    Toggle("High-temp heatbed", isOn: $highTempHeatbed)
                } footer: {
                    Text("Selected routines run on the printer and may take several minutes.")
                }
            }
            .navigationTitle("Calibration")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        Task { await model.calibrate(printer, options: options) }
                        dismiss()
                    }
                    .disabled(!options.hasSelection)
                }
            }
        }
    }
}

/// Feuille de sélection des objets à ignorer sur la plaque courante.
struct SkipObjectsSheet: View {
    let printer: Printer
    let model: PrinterListModel

    @Environment(\.dismiss) private var dismiss
    @State private var objects: [PrintObject] = []
    @State private var selection: Set<Int> = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Skip objects")
                .toolbarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Skip") {
                            Task { await model.skipObjects(printer, objectIDs: Array(selection)) }
                            dismiss()
                        }
                        .disabled(selection.isEmpty)
                    }
                }
                .task { await reload() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
        } else if objects.isEmpty {
            ContentUnavailableView(
                "No objects",
                systemImage: "square.dashed",
                description: Text("This print has no skippable objects yet.")
            )
        } else {
            List(objects) { object in
                Button {
                    toggle(object)
                } label: {
                    HStack {
                        Text(object.name)
                            .foregroundStyle(object.skipped ? .secondary : .primary)
                        Spacer()
                        if object.skipped {
                            Text("Skipped").font(.caption).foregroundStyle(.secondary)
                        } else if selection.contains(object.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(object.skipped)
            }
        }
    }

    private func toggle(_ object: PrintObject) {
        if selection.contains(object.id) {
            selection.remove(object.id)
        } else {
            selection.insert(object.id)
        }
    }

    private func reload() async {
        isLoading = true
        if let result = await model.printObjects(for: printer) {
            objects = result.objects
        }
        isLoading = false
    }
}
