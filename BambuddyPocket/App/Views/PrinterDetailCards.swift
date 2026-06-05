// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Carte de section du détail imprimante : en-tête de section (titre en capitales atténué) au-dessus
/// d'une surface de carte. Donne la **hiérarchie** réclamée par la refonte (#5) : des groupes
/// cohérents (Statut, Impression, Températures, AMS, Ventilateurs, …) plutôt qu'une liste brute.
struct PrinterDetailCard<Content: View>: View {
    let titleKey: LocalizedStringKey
    let systemImage: String?
    @ViewBuilder let content: Content

    init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(spacing: DSSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textMuted)
                }
                Text(titleKey)
                    .font(DSFont.captionMedium)
                    .textCase(.uppercase)
                    .foregroundStyle(DSColor.textMuted)
                    .accessibilityAddTraits(.isHeader)
            }
            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    content
                }
            }
        }
    }
}

/// Ligne clé/valeur dans une carte (équivalent `LabeledContent` mais sur surface de carte).
struct PrinterDetailRow<Value: View>: View {
    let titleKey: LocalizedStringKey
    @ViewBuilder let value: Value

    init(_ titleKey: LocalizedStringKey, @ViewBuilder value: () -> Value) {
        self.titleKey = titleKey
        self.value = value()
    }

    var body: some View {
        HStack {
            Text(titleKey)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textSecondary)
            Spacer(minLength: DSSpacing.md)
            value
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

extension PrinterDetailRow where Value == Text {
    /// Surcharge texte simple (valeur déjà formatée).
    init(_ titleKey: LocalizedStringKey, value: String) {
        self.init(titleKey) { Text(value) }
    }
}

// MARK: - Cartes lecture seule (températures, ventilateurs, informations)

/// Carte « Températures » : buse(s), plateau, chambre — adaptative aux capacités du modèle.
struct PrinterTemperatureCard: View {
    let status: PrinterStatus?
    let capabilities: PrinterCapabilities

    private var showsSecondNozzle: Bool {
        status?.showsSecondNozzle(capabilities: capabilities) ?? false
    }

    var body: some View {
        if let temps = status?.temperatures {
            PrinterDetailCard("Temperatures", systemImage: "thermometer.medium") {
                if showsSecondNozzle {
                    row("Nozzle 1", temps.nozzle, temps.nozzleTarget)
                    row("Nozzle 2", temps.nozzle2, temps.nozzle2Target)
                    if let active = status?.activeExtruder {
                        PrinterDetailRow(
                            "Active extruder",
                            value: PrinterPresentation.activeExtruderLabel(active)
                        )
                    }
                } else {
                    row("Nozzle", temps.nozzle, temps.nozzleTarget)
                }
                row("Bed", temps.bed, temps.bedTarget)
                if temps.chamber != nil {
                    row("Chamber", temps.chamber, temps.chamberTarget)
                }
            }
        }
    }

    private func row(_ title: LocalizedStringKey, _ current: Double?, _ target: Double?) -> some View {
        PrinterDetailRow(title, value: PrinterPresentation.temperaturePair(current, target))
    }
}

/// Carte « Ventilateurs » : chaque ventilateur n'apparaît que si sa vitesse est rapportée.
struct PrinterFansCard: View {
    let status: PrinterStatus?

    private var hasAnyFan: Bool {
        guard let status else { return false }
        return status.coolingFanSpeed != nil || status.bigFan1Speed != nil
    }

    var body: some View {
        if hasAnyFan, let status {
            PrinterDetailCard("Fans", systemImage: "fan") {
                if let speed = status.coolingFanSpeed {
                    PrinterDetailRow("Part cooling", value: "\(speed)%")
                }
                if let speed = status.bigFan1Speed {
                    PrinterDetailRow("Auxiliary", value: "\(speed)%")
                }
                if let speed = status.bigFan2Speed {
                    PrinterDetailRow("Chamber fan", value: "\(speed)%")
                }
                if let speed = status.heatbreakFanSpeed {
                    PrinterDetailRow("Heatbreak", value: "\(speed)%")
                }
            }
        }
    }
}

/// Carte « Informations » : modèle, firmware, réseau adaptatif, numéro de série, IP.
struct PrinterInfoCard: View {
    let printer: Printer
    let status: PrinterStatus?
    let capabilities: PrinterCapabilities

    var body: some View {
        PrinterDetailCard("Information", systemImage: "info.circle") {
            if let value = printer.model {
                PrinterDetailRow("Model", value: value)
            }
            if let value = status?.firmwareVersion {
                PrinterDetailRow("Firmware", value: value)
            }
            networkRow
            if let value = printer.serialNumber {
                PrinterDetailRow("Serial number", value: value)
            }
            if let value = printer.ipAddress {
                PrinterDetailRow("IP address", value: value)
            }
        }
    }

    @ViewBuilder
    private var networkRow: some View {
        if capabilities.hasEthernet, status?.wiredNetwork == true {
            PrinterDetailRow("Network", value: String(localized: "Ethernet"))
        } else if let signal = status?.wifiSignal {
            PrinterDetailRow("Wi-Fi", value: PrinterPresentation.wifiSignal(signal))
        }
    }
}

/// Carte « Impression en cours » (lecture seule) : nom, progression, couche, temps restant.
struct PrinterCurrentPrintCard: View {
    let status: PrinterStatus

    var body: some View {
        PrinterDetailCard("Current print", systemImage: "printer.fill") {
            if let name = status.subtaskName ?? status.currentPrint {
                PrinterDetailRow("Job", value: name)
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
                PrinterDetailRow("Layer", value: "\(layer) / \(total)")
            }
            if let remaining = PrinterPresentation.remainingTime(minutes: status.remainingTime) {
                PrinterDetailRow("Remaining", value: remaining)
            }
        }
    }
}
