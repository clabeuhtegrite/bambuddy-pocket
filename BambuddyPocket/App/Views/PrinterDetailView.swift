// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Détail temps réel d'une imprimante : état, progression, températures, erreurs HMS, AMS.
struct PrinterDetailView: View {
    let printer: Printer
    let model: PrinterListModel

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingStop = false
    @State private var confirmingDelete = false
    @State private var showingCalibration = false
    @State private var showingSkipObjects = false
    @State private var showingEdit = false

    private var status: PrinterStatus? {
        model.status(for: printer)
    }

    /// Capacités matérielles déduites du modèle (source : `Printer.model`, fiable).
    private var capabilities: PrinterCapabilities {
        printer.capabilities
    }

    var body: some View {
        List {
            heroHeaderSection
            statusSection
            cameraLink
            deviceSection
            if let status, status.isPrinting {
                PrinterPrintSection(status: status)
                controlsSection(status)
            }
            PrinterReadoutSections(status: status, capabilities: capabilities)
            if let status, status.hasActiveErrors {
                errorsSection(status)
            }
            amsSection
            maintenanceSection
            printOptionsSection
            informationSection
            managementSection
        }
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
        .navigationTitle(printer.name)
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCalibration) {
            CalibrationSheet(printer: printer, model: model)
        }
        .sheet(isPresented: $showingSkipObjects) {
            SkipObjectsSheet(printer: printer, model: model)
        }
        .sheet(isPresented: $showingEdit) {
            EditPrinterSheet(printer: printer, model: model)
        }
        .confirmationDialog("Stop print?", isPresented: $confirmingStop, titleVisibility: .visible) {
            Button("Stop", role: .destructive) {
                Task { await model.stop(printer) }
            }
        } message: {
            Text("This will cancel the current print.")
        }
        .confirmationDialog(
            "Remove printer?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                Task {
                    if await model.deletePrinter(printer) {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("This removes the printer from the server.")
        }
        .alert(
            "Action failed",
            isPresented: Binding(get: { model.controlError != nil }, set: { if !$0 { model.controlError = nil } })
        ) {
            Button("OK", role: .cancel) { model.controlError = nil }
        } message: {
            Text(model.controlError ?? "")
        }
    }

    /// En-tête enrichi (proposition B) : flux caméra/rendu, strip de températures, strip AMS coloré.
    private var heroHeaderSection: some View {
        Section {
            PrinterDetailHero(printer: printer, model: model, status: status, capabilities: capabilities)
        }
    }

    private func controlsSection(_ status: PrinterStatus) -> some View {
        Section("Controls") {
            if status.state == .pause {
                Button {
                    Task { await model.resume(printer) }
                } label: {
                    Label("Resume", systemImage: "play.fill")
                }
            } else {
                Button {
                    Task { await model.pause(printer) }
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
            }
            Button(role: .destructive) {
                confirmingStop = true
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            Picker("Speed", selection: speedBinding(current: status.speedLevel)) {
                Text("Silent").tag(1)
                Text("Standard").tag(2)
                Text("Sport").tag(3)
                Text("Ludicrous").tag(4)
            }
            Button {
                showingSkipObjects = true
            } label: {
                Label("Skip objects", systemImage: "square.on.square.dashed")
            }
        }
    }

    @ViewBuilder
    private var deviceSection: some View {
        if status?.connected == true {
            Section("Device") {
                Toggle("Chamber light", isOn: lightBinding)
                Button("Unload filament") {
                    Task { await model.unloadFilament(printer) }
                }
                Button("Clear plate") {
                    Task { await model.clearPlate(printer) }
                }
                Button("Disconnect") {
                    Task { await model.disconnect(printer) }
                }
            }
        } else {
            Section("Device") {
                Button("Connect") {
                    Task { await model.connect(printer) }
                }
            }
        }
    }

    private var lightBinding: Binding<Bool> {
        Binding(
            get: { status?.chamberLight ?? false },
            set: { newValue in Task { await model.setChamberLight(printer, on: newValue) } }
        )
    }

    private func speedBinding(current: Int?) -> Binding<Int> {
        Binding(
            get: { current ?? 2 },
            set: { newValue in Task { await model.setSpeed(printer, mode: newValue) } }
        )
    }

    private var statusSection: some View {
        Section("Status") {
            StateBadge(state: status?.liveState, connected: status?.connected)
            if let stage = status?.displayableStage {
                LabeledContent("Stage", value: stage)
            }
        }
    }

    /// Caméra disponible ? Capacité modèle **et** statut ne signalant pas explicitement l'absence
    /// (`ipcam == false`). On reste permissif si le statut n'expose pas `ipcam` (nil).
    private var showsCamera: Bool {
        capabilities.hasCamera && status?.ipcam != false
    }

    private var cameraLink: some View {
        Section {
            if showsCamera {
                NavigationLink {
                    CameraView(printer: printer, model: model)
                } label: {
                    Label("Camera", systemImage: "video")
                }
            }
            NavigationLink {
                KProfilesView(printer: printer, model: model)
            } label: {
                Label("Pressure advance", systemImage: "scope")
            }
        }
    }

    private func errorsSection(_ status: PrinterStatus) -> some View {
        // Seules les erreurs **alarmantes** (gravité effective ≥ serious) sont listées : les codes
        // informatifs/de statut que la gamme H2D/X2D émet en continu sont filtrés à la source.
        Section("Errors") {
            ForEach(status.alarmingErrors) { error in
                HMSErrorRow(error: error)
            }
            Button("Clear errors") {
                Task { await model.clearErrors(printer) }
            }
        }
    }

    @ViewBuilder
    private var amsSection: some View {
        if let units = status?.ams, !units.isEmpty {
            ForEach(units) { unit in
                AMSUnitSection(
                    unit: unit,
                    capabilities: capabilities,
                    printer: printer,
                    model: model
                )
            }
        }
    }

    @ViewBuilder
    private var maintenanceSection: some View {
        if status?.connected == true {
            Section("Maintenance") {
                Button {
                    Task { await model.homeAxes(printer) }
                } label: {
                    Label("Home axes", systemImage: "house")
                }
                Button {
                    showingCalibration = true
                } label: {
                    Label("Calibration", systemImage: "scope")
                }
                BedJogControl(printer: printer, model: model)
                if let mode = status?.airductMode {
                    AirductPicker(printer: printer, model: model, current: mode)
                }
            }
        }
    }

    @ViewBuilder
    private var printOptionsSection: some View {
        if status?.connected == true, let options = status?.printOptions {
            PrintOptionsSection(printer: printer, model: model, options: options)
        }
    }

    private var managementSection: some View {
        Section {
            Button {
                showingEdit = true
            } label: {
                Label("Edit printer", systemImage: "pencil")
            }
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Remove printer", systemImage: "trash")
            }
        }
    }

    private var informationSection: some View {
        PrinterInfoSection(printer: printer, status: status, capabilities: capabilities)
    }
}

/// Section « Informations » : modèle, firmware, réseau (adaptatif), numéro de série, adresse IP.
private struct PrinterInfoSection: View {
    let printer: Printer
    let status: PrinterStatus?
    let capabilities: PrinterCapabilities

    var body: some View {
        Section("Information") {
            if let value = printer.model {
                LabeledContent("Model", value: value)
            }
            if let value = status?.firmwareVersion {
                LabeledContent("Firmware", value: value)
            }
            networkRow
            if let value = printer.serialNumber {
                LabeledContent("Serial number", value: value)
            }
            if let value = printer.ipAddress {
                LabeledContent("IP address", value: value)
            }
        }
    }

    /// Connectivité réseau adaptative :
    /// - Ethernet affiché uniquement si le modèle a un port **et** que le statut le rapporte câblé.
    /// - Sinon, Wi-Fi avec la force du signal si le statut l'expose.
    /// - Rien si aucune donnée réseau n'est disponible (offline / firmware ancien).
    @ViewBuilder
    private var networkRow: some View {
        if capabilities.hasEthernet, status?.wiredNetwork == true {
            LabeledContent("Network", value: String(localized: "Ethernet"))
        } else if let signal = status?.wifiSignal {
            LabeledContent("Wi-Fi", value: PrinterPresentation.wifiSignal(signal))
        }
    }
}

/// Section « Impression en cours » (lecture seule) : nom, progression, couche, temps restant.
private struct PrinterPrintSection: View {
    let status: PrinterStatus

    var body: some View {
        Section("Current print") {
            if let name = status.subtaskName ?? status.currentPrint {
                LabeledContent("Job", value: name)
            }
            if let fraction = status.progressFraction {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    ProgressView(value: fraction)
                        .tint(DSColor.accent)
                    Text("\(Int((status.progress ?? 0).rounded()))%")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
            }
            if let layer = status.layerNum, let total = status.totalLayers, total > 0 {
                LabeledContent("Layer", value: "\(layer) / \(total)")
            }
            if let remaining = PrinterPresentation.remainingTime(minutes: status.remainingTime) {
                LabeledContent("Remaining", value: remaining)
            }
        }
    }
}

/// Contrôle d'ajustement de l'écart buse-plateau (`bed-jog`) par pas de 0,1 mm.
private struct BedJogControl: View {
    let printer: Printer
    let model: PrinterListModel

    var body: some View {
        HStack {
            Label("Nozzle-bed gap", systemImage: "arrow.up.and.down")
            Spacer()
            Button {
                Task { await model.bedJog(printer, distance: -0.1) }
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Decrease gap by 0.1 mm")
            Button {
                Task { await model.bedJog(printer, distance: 0.1) }
            } label: {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Increase gap by 0.1 mm")
        }
    }
}

/// Sélecteur du mode du conduit d'air (refroidissement / chauffage) sur les modèles compatibles.
private struct AirductPicker: View {
    let printer: Printer
    let model: PrinterListModel
    let current: Int

    var body: some View {
        Picker("Airduct", selection: binding) {
            Text("Cooling").tag("cooling")
            Text("Heating").tag("heating")
        }
    }

    private var binding: Binding<String> {
        Binding(
            get: { current == 1 ? "heating" : "cooling" },
            set: { newValue in Task { await model.setAirductMode(printer, mode: newValue) } }
        )
    }
}

/// Section des options d'impression / détection IA (lecture + bascule), `print-options`.
private struct PrintOptionsSection: View {
    let printer: Printer
    let model: PrinterListModel
    let options: PrintOptions

    var body: some View {
        Section("Print options") {
            toggle("Spaghetti detection", module: "spaghetti_detector", on: options.spaghettiDetector)
            toggle("First layer inspection", module: "first_layer_inspector", on: options.firstLayerInspector)
            toggle("AI quality monitor", module: "printing_monitor", on: options.printingMonitor)
            toggle("Allow skipping parts", module: "allow_skip_parts", on: options.allowSkipParts)
        }
    }

    private func toggle(_ titleKey: LocalizedStringKey, module: String, on: Bool?) -> some View {
        Toggle(titleKey, isOn: Binding(
            get: { on ?? false },
            set: { newValue in Task { await model.setPrintOption(printer, moduleName: module, enabled: newValue) } }
        ))
    }
}

/// Ligne d'une erreur HMS alarmante : icône colorée par gravité, libellé humain, code court lisible
/// (avec lien wiki Bambu si disponible) et gravité.
private struct HMSErrorRow: View {
    let error: HMSError

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(PrinterPresentation.severityColor(error.effectiveSeverity))
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(PrinterPresentation.hmsTitle(error))
                codeLabel
                Text(PrinterPresentation.severityText(error.effectiveSeverity))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var codeLabel: some View {
        if let url = error.wikiURL {
            Link(destination: url) {
                HStack(spacing: DSSpacing.xs) {
                    Text(error.displayCode).font(.subheadline.monospaced())
                    Image(systemName: "arrow.up.right.square")
                }
            }
            .font(.subheadline)
        } else {
            Text(error.displayCode).font(.subheadline.monospaced())
        }
    }
}
