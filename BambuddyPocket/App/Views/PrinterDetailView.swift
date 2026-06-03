// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Détail temps réel d'une imprimante : état, progression, températures, erreurs HMS, AMS.
struct PrinterDetailView: View {
    let printer: Printer
    let model: PrinterListModel

    @State private var confirmingStop = false

    private var status: PrinterStatus? {
        model.status(for: printer)
    }

    var body: some View {
        List {
            statusSection
            if let status, status.isPrinting {
                printSection(status)
                controlsSection(status)
            }
            temperatureSection
            if let status, status.hasActiveErrors {
                errorsSection(status)
            }
            amsSection
            informationSection
        }
        .navigationTitle(printer.name)
        .toolbarTitleDisplayMode(.inline)
        .confirmationDialog("Stop print?", isPresented: $confirmingStop, titleVisibility: .visible) {
            Button("Stop", role: .destructive) {
                Task { await model.stop(printer) }
            }
        } message: {
            Text("This will cancel the current print.")
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
        }
    }

    private var statusSection: some View {
        Section("Status") {
            StateBadge(state: status?.state, connected: status?.connected)
            if let stage = status?.stgCurName, !stage.isEmpty {
                LabeledContent("Stage", value: stage)
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
                Section {
                    ForEach(unit.tray ?? []) { tray in
                        TrayRow(tray: tray)
                    }
                } header: {
                    Text("AMS \(unit.id + 1)")
                }
            }
        }
    }

    private var informationSection: some View {
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
