// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

// MARK: - Contrôles d'impression

/// Carte « Contrôles » (impression active) : pause/reprise, arrêt, vitesse, ignorer des objets.
struct PrinterControlsCard: View {
    let printer: Printer
    let model: PrinterListModel
    let status: PrinterStatus
    @Binding var confirmingStop: Bool
    @Binding var showingSkipObjects: Bool

    var body: some View {
        PrinterDetailCard("Controls", systemImage: "slider.horizontal.3") {
            if status.state == .pause {
                actionButton("Resume", systemImage: "play.fill") {
                    Task { await model.resume(printer) }
                }
            } else {
                actionButton("Pause", systemImage: "pause.fill") {
                    Task { await model.pause(printer) }
                }
            }
            actionButton("Stop", systemImage: "stop.fill", role: .destructive) {
                confirmingStop = true
            }
            DSSeparator()
            Picker("Speed", selection: speedBinding) {
                Text("Silent").tag(1)
                Text("Standard").tag(2)
                Text("Sport").tag(3)
                Text("Ludicrous").tag(4)
            }
            .font(DSFont.body)
            DSSeparator()
            actionButton("Skip objects", systemImage: "square.on.square.dashed") {
                showingSkipObjects = true
            }
        }
    }

    private var speedBinding: Binding<Int> {
        Binding(
            get: { status.speedLevel ?? 2 },
            set: { newValue in Task { await model.setSpeed(printer, mode: newValue) } }
        )
    }

    private func actionButton(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(titleKey, systemImage: systemImage)
                .font(DSFont.body)
                .foregroundStyle(role == .destructive ? DSColor.statusError : DSColor.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Appareil (lumière, filament, plateau, connexion)

/// Carte « Appareil » : lumière chambre, déchargement filament, retrait plateau, connexion.
struct PrinterDeviceCard: View {
    let printer: Printer
    let model: PrinterListModel
    let status: PrinterStatus?

    var body: some View {
        PrinterDetailCard("Device", systemImage: "printer") {
            if status?.connected == true {
                Toggle("Chamber light", isOn: lightBinding)
                    .font(DSFont.body)
                DSSeparator()
                actionButton("Unload filament", systemImage: "arrow.up.bin") {
                    Task { await model.unloadFilament(printer) }
                }
                actionButton("Clear plate", systemImage: "checkmark.rectangle") {
                    Task { await model.clearPlate(printer) }
                }
                actionButton("Disconnect", systemImage: "wifi.slash") {
                    Task { await model.disconnect(printer) }
                }
            } else {
                actionButton("Connect", systemImage: "wifi") {
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

    private func actionButton(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(titleKey, systemImage: systemImage)
                .font(DSFont.body)
                .foregroundStyle(DSColor.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Maintenance

/// Carte « Maintenance » : prise d'origine, calibration, écart buse-plateau, conduit d'air.
struct PrinterMaintenanceCard: View {
    let printer: Printer
    let model: PrinterListModel
    let status: PrinterStatus?
    @Binding var showingCalibration: Bool

    var body: some View {
        PrinterDetailCard("Maintenance", systemImage: "wrench.and.screwdriver") {
            Button {
                Task { await model.homeAxes(printer) }
            } label: {
                Label("Home axes", systemImage: "house")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button {
                showingCalibration = true
            } label: {
                Label("Calibration", systemImage: "scope")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            DSSeparator()
            PrinterBedJogControl(printer: printer, model: model)
            if let mode = status?.airductMode {
                DSSeparator()
                PrinterAirductPicker(printer: printer, model: model, current: mode)
            }
        }
    }
}

/// Ajustement de l'écart buse-plateau (`bed-jog`) par pas de 0,1 mm.
struct PrinterBedJogControl: View {
    let printer: Printer
    let model: PrinterListModel

    var body: some View {
        HStack {
            Label("Nozzle-bed gap", systemImage: "arrow.up.and.down")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
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
struct PrinterAirductPicker: View {
    let printer: Printer
    let model: PrinterListModel
    let current: Int

    var body: some View {
        Picker("Airduct", selection: binding) {
            Text("Cooling").tag("cooling")
            Text("Heating").tag("heating")
        }
        .font(DSFont.body)
    }

    private var binding: Binding<String> {
        Binding(
            get: { current == 1 ? "heating" : "cooling" },
            set: { newValue in Task { await model.setAirductMode(printer, mode: newValue) } }
        )
    }
}

// MARK: - Options d'impression / détection IA

/// Carte « Options d'impression » : bascules de détection IA (`print-options`).
struct PrinterPrintOptionsCard: View {
    let printer: Printer
    let model: PrinterListModel
    let options: PrintOptions

    var body: some View {
        PrinterDetailCard("Print options", systemImage: "eye") {
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
        .font(DSFont.body)
    }
}

// MARK: - Erreurs HMS

/// Carte « Erreurs » : erreurs HMS alarmantes (gravité ≥ serious) + effacement.
struct PrinterErrorsCard: View {
    let printer: Printer
    let model: PrinterListModel
    let status: PrinterStatus

    var body: some View {
        PrinterDetailCard("Errors", systemImage: "exclamationmark.triangle") {
            ForEach(Array(status.alarmingErrors.enumerated()), id: \.element.id) { index, error in
                if index > 0 { DSSeparator() }
                PrinterHMSErrorRow(error: error)
            }
            DSSeparator()
            Button {
                Task { await model.clearErrors(printer) }
            } label: {
                Label("Clear errors", systemImage: "xmark.circle")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Ligne d'une erreur HMS alarmante : icône colorée par gravité, libellé humain, code court lisible.
struct PrinterHMSErrorRow: View {
    let error: HMSError

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(PrinterPresentation.severityColor(error.effectiveSeverity))
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(PrinterPresentation.hmsTitle(error))
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
                codeLabel
                Text(PrinterPresentation.severityText(error.effectiveSeverity))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer()
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

// MARK: - Liens (caméra, pressure advance) + gestion destructive

/// Carte « Liens » : caméra (si disponible) et profils de pression (pressure advance).
struct PrinterLinksCard: View {
    let printer: Printer
    let model: PrinterListModel
    let showsCamera: Bool

    var body: some View {
        PrinterDetailCard("More", systemImage: "ellipsis.circle") {
            if showsCamera {
                NavigationLink {
                    CameraView(printer: printer, model: model)
                } label: {
                    linkLabel("Camera", systemImage: "video")
                }
                DSSeparator()
            }
            NavigationLink {
                KProfilesView(printer: printer, model: model)
            } label: {
                linkLabel("Pressure advance", systemImage: "scope")
            }
        }
    }

    private func linkLabel(_ titleKey: LocalizedStringKey, systemImage: String) -> some View {
        HStack {
            Label(titleKey, systemImage: systemImage)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textMuted)
        }
    }
}

/// Carte de **gestion** : modifier (action neutre) et, dans une **zone destructive dédiée**,
/// supprimer l'imprimante avec confirmation — au lieu d'être noyé en bas de liste (#6).
struct PrinterManagementCard: View {
    let printer: Printer
    @Binding var showingEdit: Bool
    @Binding var confirmingDelete: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            PrinterDetailCard("Manage", systemImage: "gearshape") {
                Button {
                    showingEdit = true
                } label: {
                    HStack {
                        Label("Edit printer", systemImage: "pencil")
                            .font(DSFont.body)
                            .foregroundStyle(DSColor.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(DSFont.caption)
                            .foregroundStyle(DSColor.textMuted)
                    }
                }
                .buttonStyle(.plain)
            }

            // Zone destructive dédiée, visuellement distincte (#6).
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Remove printer", systemImage: "trash")
                    .font(DSFont.bodyMedium)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.dsDestructive)
            .accessibilityHint(Text("Removes the printer from the server"))
        }
    }
}
