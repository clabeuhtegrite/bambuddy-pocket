// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Feuille « Imprimer » : sélection de l'imprimante cible (connectée), options d'impression, puis
/// dispatch vers le serveur (`POST …/print` ou `…/reprint`). Le travail réel (send/start) est
/// asynchrone côté serveur ; la feuille se ferme dès la mise en file confirmée.
struct PrintSheet: View {
    @State private var model: PrintDispatchModel
    @Environment(\.dismiss) private var dismiss

    /// Plaque saisie librement (numéro) — `nil`/vide ⇒ auto-détection côté serveur.
    @State private var plateNumber = ""
    @State private var showDispatched = false

    init(model: PrintDispatchModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            Form {
                sourceSection
                printerSection
                plateSection
                optionsSection
                if let error = model.error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(DSColor.statusError)
                    }
                }
            }
            .dsListBackground()
            .navigationTitle("Print")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if model.isDispatching {
                        ProgressView()
                    } else {
                        Button("Print") { dispatch() }
                            .disabled(!model.canDispatch)
                    }
                }
            }
            .task {
                if !model.hasLoaded { await model.load() }
            }
            .alert("Print dispatched", isPresented: $showDispatched) {
                Button("OK", role: .cancel) { dismiss() }
            } message: {
                Text("The print job has been sent to the printer.")
            }
        }
    }

    private var sourceSection: some View {
        Section("Model") {
            LabeledContent("File", value: model.source.displayName)
        }
    }

    private var printerSection: some View {
        Section("Printer") {
            if !model.hasLoaded {
                HStack {
                    ProgressView()
                    Text("Loading printers…")
                        .foregroundStyle(DSColor.textSecondary)
                }
            } else if model.targets.isEmpty {
                Text("No printers available")
                    .foregroundStyle(DSColor.textSecondary)
            } else {
                Picker("Printer", selection: $model.selectedPrinterID) {
                    ForEach(model.targets) { target in
                        printerRow(target).tag(Int?.some(target.id))
                    }
                }
                if selectedTargetIsOffline {
                    Text("This printer is offline. Connect it before printing.")
                        .font(.footnote)
                        .foregroundStyle(DSColor.statusWarning)
                }
            }
        }
    }

    /// `true` quand la cible sélectionnée existe mais est hors ligne (avertissement non bloquant).
    private var selectedTargetIsOffline: Bool {
        guard let id = model.selectedPrinterID else { return false }
        return model.targets.first { $0.id == id }?.isConnected == false
    }

    private func printerRow(_ target: PrintDispatchModel.Target) -> some View {
        HStack {
            Text(target.printer.name)
            if !target.isConnected {
                Text("Offline")
                    .font(.caption2)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }

    private var plateSection: some View {
        Section {
            TextField("Plate number (optional)", text: $plateNumber)
                .keyboardType(.numberPad)
                .onChange(of: plateNumber) { _, value in
                    let trimmed = value.trimmingCharacters(in: .whitespaces)
                    model.options.plateId = Int(trimmed)
                }
        } header: {
            Text("Plate")
        } footer: {
            Text("Leave empty to auto-detect the plate from the sliced file.")
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            Toggle("Bed levelling", isOn: $model.options.bedLevelling)
            Toggle("Flow calibration", isOn: $model.options.flowCali)
            Toggle("Vibration calibration", isOn: $model.options.vibrationCali)
            Toggle("Layer inspection", isOn: $model.options.layerInspect)
            Toggle("Timelapse", isOn: $model.options.timelapse)
            Toggle("Use AMS", isOn: $model.options.useAms)
        }
    }

    private func dispatch() {
        Task {
            if await model.dispatch() {
                showDispatched = true
            }
        }
    }
}
