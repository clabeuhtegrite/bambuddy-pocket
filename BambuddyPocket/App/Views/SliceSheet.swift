// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Feuille « Trancher » (découpe) : choix des présets (imprimante / process / filament) et de la
/// plaque, soumission du job de découpe, suivi de la progression, puis résultat. Le fichier tranché
/// atterrit dans la bibliothèque ; il pourra être imprimé via le flux « Imprimer » existant —
/// **aucune impression n'est lancée automatiquement**.
struct SliceSheet: View {
    @State private var model: SliceJobModel
    @Environment(\.dismiss) private var dismiss

    /// Appelé à la fermeture après une découpe réussie, pour rafraîchir la bibliothèque.
    let onCompleted: () -> Void

    init(model: SliceJobModel, onCompleted: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onCompleted = onCompleted
    }

    var body: some View {
        NavigationStack {
            content
                .dsListBackground()
                .navigationTitle("Slice")
                .toolbarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .task {
                    if model.presets == nil { await model.loadPresets() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loadingPresets:
            loadingView(String(localized: "Loading slicer presets…"))
        case .ready:
            presetForm
        case let .slicing(progress):
            slicingView(progress)
        case let .completed(result):
            completedView(result)
        case let .failed(message):
            failedView(message)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            switch model.phase {
            case .ready:
                Button("Slice") { Task { await model.slice() } }
                    .disabled(!model.canSlice)
                    .accessibilityIdentifier("slice-submit")
            case .completed:
                Button("Done") {
                    onCompleted()
                    dismiss()
                }
            default:
                EmptyView()
            }
        }
    }

    // MARK: Formulaire de présets

    private var presetForm: some View {
        Form {
            Section("File") {
                LabeledContent("Model", value: model.fileName)
            }
            if let presets = model.presets {
                presetPicker("Printer", selection: $model.selectedPrinter, options: presets.allPrinters)
                presetPicker("Process", selection: $model.selectedProcess, options: presets.allProcesses)
                presetPicker("Filament", selection: $model.selectedFilament, options: presets.allFilaments)
            }
            Section {
                Text("The sliced file will be added to your library. Nothing is printed automatically.")
                    .font(.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }

    private func presetPicker(
        _ title: LocalizedStringKey,
        selection: Binding<UnifiedPreset?>,
        options: [UnifiedPreset]
    ) -> some View {
        Section(title) {
            if options.isEmpty {
                Text("None available")
                    .foregroundStyle(DSColor.textSecondary)
            } else {
                Picker(title, selection: selection) {
                    ForEach(options) { preset in
                        Text(preset.name).tag(UnifiedPreset?.some(preset))
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    // MARK: États

    private func loadingView(_ label: String) -> some View {
        VStack(spacing: DSSpacing.md) {
            ProgressView()
            Text(label).foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func slicingView(_ progress: Double?) -> some View {
        VStack(spacing: DSSpacing.md) {
            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, DSSpacing.xl)
                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.headline)
            } else {
                ProgressView()
            }
            Text("Slicing \(model.fileName)…")
                .foregroundStyle(DSColor.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("slice-progress")
    }

    private func completedView(_ result: SliceResult) -> some View {
        Form {
            Section {
                Label("Slicing complete", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(DSColor.statusOK)
            }
            Section("Result") {
                if let name = result.name {
                    LabeledContent("File", value: name)
                }
                if let time = ArchivePresentation.duration(seconds: result.printTimeSeconds) {
                    LabeledContent("Print time", value: time)
                }
                if let filament = ArchivePresentation.filament(grams: result.filamentUsedG) {
                    LabeledContent("Filament", value: filament)
                }
            }
            Section {
                Text("Added to your library. Open it to print or add it to the queue.")
                    .font(.footnote)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(DSColor.statusError)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(DSColor.textSecondary)
                .padding(.horizontal, DSSpacing.xl)
            Button("Retry") { Task { await model.loadPresets() } }
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
