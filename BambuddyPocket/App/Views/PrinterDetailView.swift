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

    private var status: PrinterStatus? {
        model.status(for: printer)
    }

    var body: some View {
        List {
            statusSection
            cameraLink
            deviceSection
            if let status, status.isPrinting {
                printSection(status)
                controlsSection(status)
            }
            PrinterReadoutSections(status: status)
            if let status, status.hasActiveErrors {
                errorsSection(status)
            }
            amsSection
            maintenanceSection
            informationSection
            managementSection
        }
        .navigationTitle(printer.name)
        .toolbarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingCalibration) {
            CalibrationSheet(printer: printer, model: model)
        }
        .sheet(isPresented: $showingSkipObjects) {
            SkipObjectsSheet(printer: printer, model: model)
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
            StateBadge(state: status?.state, connected: status?.connected)
            if let stage = status?.stgCurName, !stage.isEmpty {
                LabeledContent("Stage", value: stage)
            }
        }
    }

    private var cameraLink: some View {
        Section {
            NavigationLink {
                CameraView(printer: printer, model: model)
            } label: {
                Label("Camera", systemImage: "video")
            }
        }
    }

    private func printSection(_ status: PrinterStatus) -> some View {
        Section("Current print") {
            if let name = status.subtaskName ?? status.currentPrint {
                LabeledContent("Job", value: name)
            }
            if let fraction = status.progressFraction {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    ProgressView(value: fraction)
                    Text("\(Int((status.progress ?? 0).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

    private func errorsSection(_ status: PrinterStatus) -> some View {
        Section("Errors") {
            ForEach(status.hmsErrors ?? []) { error in
                HStack(spacing: DSSpacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(PrinterPresentation.severityColor(error.severityLevel))
                    VStack(alignment: .leading, spacing: DSSpacing.xs) {
                        Text(error.code).font(.subheadline.monospaced())
                        Text(PrinterPresentation.severityText(error.severityLevel))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
                AMSUnitSection(unit: unit, printer: printer, model: model)
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
            }
        }
    }

    private var managementSection: some View {
        Section {
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Remove printer", systemImage: "trash")
            }
        }
    }

    private var informationSection: some View {
        PrinterInfoSection(printer: printer, status: status)
    }
}

/// Sections en lecture seule : températures, ventilateurs et informations matérielles.
private struct PrinterReadoutSections: View {
    let status: PrinterStatus?

    var body: some View {
        temperatureSection
        fansSection
    }

    @ViewBuilder
    private var temperatureSection: some View {
        if let temps = status?.temperatures {
            Section("Temperatures") {
                temperatureRow("Nozzle", temps.nozzle, temps.nozzleTarget)
                temperatureRow("Bed", temps.bed, temps.bedTarget)
                if temps.chamber != nil {
                    temperatureRow("Chamber", temps.chamber, temps.chamberTarget)
                }
            }
        }
    }

    private func temperatureRow(_ label: LocalizedStringKey, _ current: Double?, _ target: Double?) -> some View {
        LabeledContent(label, value: PrinterPresentation.temperaturePair(current, target))
    }

    @ViewBuilder
    private var fansSection: some View {
        if let status, status.coolingFanSpeed != nil || status.bigFan1Speed != nil {
            Section("Fans") {
                if let speed = status.coolingFanSpeed {
                    LabeledContent("Part cooling", value: "\(speed)%")
                }
                if let speed = status.bigFan1Speed {
                    LabeledContent("Auxiliary", value: "\(speed)%")
                }
                if let speed = status.bigFan2Speed {
                    LabeledContent("Chamber fan", value: "\(speed)%")
                }
            }
        }
    }
}

/// Section « Informations » : modèle, firmware, numéro de série, adresse IP.
private struct PrinterInfoSection: View {
    let printer: Printer
    let status: PrinterStatus?

    var body: some View {
        Section("Information") {
            if let value = printer.model {
                LabeledContent("Model", value: value)
            }
            if let value = status?.firmwareVersion {
                LabeledContent("Firmware", value: value)
            }
            if let value = printer.serialNumber {
                LabeledContent("Serial number", value: value)
            }
            if let value = printer.ipAddress {
                LabeledContent("IP address", value: value)
            }
        }
    }
}

/// Section d'une unité AMS : plateaux (avec chargement par balayage) et contrôle de séchage.
private struct AMSUnitSection: View {
    let unit: AMSUnit
    let printer: Printer
    let model: PrinterListModel

    var body: some View {
        Section {
            ForEach(unit.tray ?? []) { tray in
                TrayRow(tray: tray)
                    .swipeActions(edge: .leading) {
                        Button("Load") {
                            Task { await model.loadFilament(printer, trayID: trayIndex(tray)) }
                        }
                        .tint(.blue)
                    }
            }
            if (unit.dryStatus ?? 0) > 0 {
                Button("Stop drying") {
                    Task { await model.stopDrying(printer, amsID: unit.id) }
                }
            } else {
                Button("Start drying") {
                    Task { await model.startDrying(printer, amsID: unit.id) }
                }
            }
        } header: {
            Text("AMS \(unit.id + 1)")
        }
    }

    /// Identifiant de plateau global (`ams_id * 4 + slot`) attendu par `POST /ams/load`.
    private func trayIndex(_ tray: AMSTray) -> Int {
        unit.id * 4 + tray.id
    }
}

/// Ligne d'un slot AMS : pastille de couleur, type de filament et niveau restant.
private struct TrayRow: View {
    let tray: AMSTray

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Circle()
                .fill(PrinterPresentation.color(hexRGBA: tray.trayColor) ?? .secondary)
                .frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(.quaternary))
            Text(tray.trayType ?? String(localized: "Empty"))
            Spacer()
            if let remain = tray.remain {
                Text("\(remain)%")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
