// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Détail temps réel d'une imprimante, **refonte en cartes** (#5) : un en-tête hero (flux/rendu +
/// températures), puis des **groupes cohérents** (statut, impression en cours, températures, AMS,
/// ventilateurs, erreurs, contrôles, appareil, maintenance, options, informations) en cartes, et
/// enfin une **zone de gestion** avec une action destructive dédiée (#6).
///
/// Le scroll repose sur un `ScrollView` (et non une `List`) : meilleure hiérarchie visuelle et
/// défilement fiable sous XCUITest (iOS 26 ne défile pas une `List`).
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

    /// Caméra disponible ? Capacité modèle **et** statut ne signalant pas explicitement l'absence.
    private var showsCamera: Bool {
        capabilities.hasCamera && status?.ipcam != false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                PrinterDetailHero(printer: printer, model: model, status: status, capabilities: capabilities)
                statusCard
                if let status, status.isPrinting {
                    PrinterCurrentPrintCard(status: status)
                    PrinterControlsCard(
                        printer: printer,
                        model: model,
                        status: status,
                        confirmingStop: $confirmingStop,
                        showingSkipObjects: $showingSkipObjects
                    )
                }
                PrinterTemperatureCard(status: status, capabilities: capabilities)
                amsCards
                PrinterFansCard(status: status)
                if let status, status.hasActiveErrors {
                    PrinterErrorsCard(printer: printer, model: model, status: status)
                }
                PrinterDeviceCard(printer: printer, model: model, status: status)
                maintenanceCard
                printOptionsCard
                PrinterLinksCard(printer: printer, model: model, showsCamera: showsCamera)
                PrinterInfoCard(printer: printer, status: status, capabilities: capabilities)
                PrinterManagementCard(
                    printer: printer,
                    showingEdit: $showingEdit,
                    confirmingDelete: $confirmingDelete
                )
            }
            .padding(DSSpacing.md)
        }
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

    // MARK: Cartes

    private var statusCard: some View {
        PrinterDetailCard("Status", systemImage: "circle.fill") {
            HStack {
                StateBadge(state: status?.liveState, connected: status?.connected)
                Spacer()
            }
            if let stage = status?.displayableStage {
                PrinterDetailRow("Stage", value: stage)
            }
        }
    }

    /// Une carte AMS **par unité** (#4) : layout slots calqué sur la web UI.
    @ViewBuilder
    private var amsCards: some View {
        if let units = status?.ams, !units.isEmpty {
            ForEach(units) { unit in
                PrinterAMSCard(
                    unit: unit,
                    capabilities: capabilities,
                    printer: printer,
                    model: model
                )
            }
        }
    }

    @ViewBuilder
    private var maintenanceCard: some View {
        if status?.connected == true {
            PrinterMaintenanceCard(
                printer: printer,
                model: model,
                status: status,
                showingCalibration: $showingCalibration
            )
        }
    }

    @ViewBuilder
    private var printOptionsCard: some View {
        if status?.connected == true, let options = status?.printOptions {
            PrinterPrintOptionsCard(printer: printer, model: model, options: options)
        }
    }
}
