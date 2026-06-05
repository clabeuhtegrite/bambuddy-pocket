// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

// MARK: - Carte hero (impression en cours)

/// Carte mise en avant de l'impression en cours : vignette, nom du travail, %, barre verte,
/// couche X/Y, temps restant, températures buse(s)/plateau, et contrôles Pause/Arrêter.
struct HeroPrintCard: View {
    enum Action {
        case pauseOrResume
        case stop
    }

    let snapshot: PrinterSnapshot
    let onAction: (Action) -> Void

    private var status: PrinterStatus? {
        snapshot.status
    }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                header
                if let fraction = snapshot.progressFraction {
                    ProgressView(value: fraction)
                        .tint(DSColor.accent)
                }
                statsRow
                actions
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(jobName)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Text(jobSubtitle)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: DSSpacing.sm)
            percentLabel
        }
    }

    private var thumbnail: some View {
        RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
            .fill(DSColor.surfaceTertiary)
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: "shippingbox")
                    .font(.title2)
                    .foregroundStyle(DSColor.accent)
            )
            .accessibilityHidden(true)
    }

    private var percentLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(percent)")
                .font(DSFont.inter(28, weight: .bold, relativeTo: .largeTitle))
            Text("%")
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textSecondary)
        }
        .foregroundStyle(DSColor.textPrimary)
        .accessibilityLabel(Text("\(percent)%"))
    }

    private var statsRow: some View {
        HStack(spacing: DSSpacing.sm) {
            stat(value: remainingText, label: "Remaining", highlighted: true)
            divider
            stat(value: nozzleText, label: nozzleLabel, highlighted: false)
            divider
            stat(value: PrinterPresentation.temperature(status?.temperatures?.bed), label: "Bed", highlighted: false)
        }
    }

    private func stat(value: String, label: LocalizedStringKey, highlighted: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(DSFont.bodyMedium)
                .foregroundStyle(highlighted ? DSColor.accent : DSColor.textPrimary)
            Text(label)
                .font(DSFont.caption)
                .textCase(.uppercase)
                .foregroundStyle(DSColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var divider: some View {
        Rectangle()
            .fill(DSColor.border)
            .frame(width: DSBorder.thin, height: 30)
    }

    private var actions: some View {
        HStack(spacing: DSSpacing.sm) {
            Button {
                onAction(.pauseOrResume)
            } label: {
                Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(.dsPrimary)
            Button {
                onAction(.stop)
            } label: {
                Label("Stop", systemImage: "stop.fill")
            }
            .buttonStyle(.dsSecondary)
        }
    }

    // MARK: Derived

    private var isPaused: Bool {
        status?.state == .pause
    }

    private var percent: Int {
        Int((status?.progress ?? 0).rounded())
    }

    private var jobName: String {
        status?.subtaskName ?? status?.currentPrint ?? snapshot.printer.name
    }

    private var jobSubtitle: String {
        var parts: [String] = []
        if let model = snapshot.printer.model { parts.append(model) }
        if let layer = status?.layerNum, let total = status?.totalLayers, total > 0 {
            parts.append(String(localized: "layer \(layer)/\(total)"))
        }
        return parts.joined(separator: " · ")
    }

    private var remainingText: String {
        PrinterPresentation.remainingTime(minutes: status?.remainingTime) ?? "—"
    }

    /// Températures de buse : couple gauche/droite sur double buse, sinon buse unique.
    private var nozzleText: String {
        let temperatures = status?.temperatures
        if snapshot.printer.capabilities.dualNozzle, status?.statusReportsSecondNozzle == true {
            return PrinterPresentation.temperaturePair(temperatures?.nozzle, temperatures?.nozzle2)
        }
        return PrinterPresentation.temperature(temperatures?.nozzle)
    }

    private var nozzleLabel: LocalizedStringKey {
        if snapshot.printer.capabilities.dualNozzle, status?.statusReportsSecondNozzle == true {
            return "Nozzle L / R"
        }
        return "Nozzle"
    }
}

// MARK: - Bandeau de compteurs (disposition Grille)

/// Bandeau de trois compteurs de la disposition « Grille » (maquette `06-accueil-C`) : imprimantes
/// en cours, prêtes, en alerte. Le tout est tapotable pour ouvrir l'onglet Imprimantes.
struct HomeStatStrip: View {
    let printing: Int
    let ready: Int
    let alerts: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.sm) {
                stat(value: printing, label: "Printing", tint: DSColor.accent)
                stat(value: ready, label: "Ready", tint: DSColor.textPrimary)
                stat(value: alerts, label: "Alerts", tint: alerts > 0 ? DSColor.statusWarning : DSColor.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Opens printers"))
    }

    private func stat(value: Int, label: LocalizedStringKey, tint: Color) -> some View {
        VStack(spacing: DSSpacing.xxs) {
            Text("\(value)")
                .font(DSFont.inter(24, weight: .bold, relativeTo: .title))
                .foregroundStyle(tint)
            Text(label)
                .font(DSFont.caption)
                .textCase(.uppercase)
                .foregroundStyle(DSColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.md)
        .dsCardSurface()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Bandeau d'alerte conditionnel

/// Bandeau d'alerte d'accueil (ambre/rouge selon la gravité), tapotable pour ouvrir le détail.
struct HomeAlertBanner: View {
    let alert: HomeAlert
    let onTap: () -> Void

    private var tint: Color {
        switch alert.severity {
        case .error: DSColor.statusError
        case .warning: DSColor.statusWarning
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(alert.title)
                        .font(DSFont.captionMedium)
                        .foregroundStyle(tint)
                    Text(alert.detail)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: DSSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textMuted)
                    .accessibilityHidden(true)
            }
            .padding(DSSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: DSBorder.thin)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Opens printer details"))
    }
}

// MARK: - Carte imprimante compacte

/// Carte imprimante compacte : nom, modèle, badge d'état, strip de deux mesures (buses G/D ou
/// buse/plateau), barre de progression mini et ligne %/temps si une impression tourne.
struct CompactPrinterCard: View {
    let snapshot: PrinterSnapshot

    private var status: PrinterStatus? {
        snapshot.status
    }

    private var printer: Printer {
        snapshot.printer
    }

    /// Double buse rapportée par le statut ?
    private var showsDualNozzle: Bool {
        printer.capabilities.dualNozzle && (status?.statusReportsSecondNozzle ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            header
            metricsStrip
            footer
        }
        .padding(DSSpacing.sm + DSSpacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dsCardSurface()
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(printer.name)
                    .font(DSFont.bodyMedium)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Text(modelLabel)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: DSSpacing.xs)
            StateBadge(state: status?.liveState, connected: status?.connected)
        }
    }

    private var metricsStrip: some View {
        HStack(spacing: DSSpacing.xs) {
            if showsDualNozzle {
                metric(label: "Nozzle L", value: PrinterPresentation.temperature(status?.temperatures?.nozzle))
                metric(label: "Nozzle R", value: PrinterPresentation.temperature(status?.temperatures?.nozzle2))
            } else {
                metric(label: "Nozzle", value: PrinterPresentation.temperature(status?.temperatures?.nozzle))
                metric(label: "Bed", value: PrinterPresentation.temperature(status?.temperatures?.bed))
            }
        }
    }

    private func metric(label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(DSFont.caption)
                .textCase(.uppercase)
                .foregroundStyle(DSColor.textMuted)
            Text(value)
                .font(DSFont.captionMedium)
                .foregroundStyle(DSColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DSSpacing.xs)
        .padding(.horizontal, DSSpacing.sm)
        .background(DSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous)
                .strokeBorder(DSColor.border, lineWidth: DSBorder.thin)
        )
    }

    @ViewBuilder
    private var footer: some View {
        if let fraction = snapshot.progressFraction {
            ProgressView(value: fraction)
                .tint(DSColor.accent)
            HStack {
                Text("\(Int((status?.progress ?? 0).rounded()))%")
                Spacer()
                Text(PrinterPresentation.remainingTime(minutes: status?.remainingTime) ?? "—")
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
        } else {
            HStack {
                Text(idleLabel)
                Spacer()
                Text("—")
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
        }
    }

    private var modelLabel: String {
        if printer.capabilities.dualNozzle {
            return String(localized: "Dual nozzle")
        }
        return printer.model ?? String(localized: "Single nozzle")
    }

    private var idleLabel: String {
        if status?.connected == false {
            return String(localized: "Offline")
        }
        return String(localized: "Idle")
    }
}

// MARK: - Chip d'action rapide

/// Pastille d'action rapide (icône accent + libellé), capsule sur surface de carte.
struct QuickActionChip: View {
    let titleKey: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(titleKey, systemImage: systemImage)
                .font(DSFont.captionMedium)
                .foregroundStyle(DSColor.textPrimary)
                .labelStyle(ChipLabelStyle())
                .padding(.vertical, DSSpacing.sm)
                .padding(.horizontal, DSSpacing.md)
                .dsCardSurface()
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Style de label des chips : icône en accent, texte en couleur primaire.
private struct ChipLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: DSSpacing.xs) {
            configuration.icon
                .foregroundStyle(DSColor.accent)
            configuration.title
        }
    }
}

// MARK: - Ligne d'activité récente

/// Ligne d'activité récente : icône catégorisée, titre, sous-titre, et horodatage relatif.
struct RecentActivityRow: View {
    let note: AppNotification

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Image(systemName: NotificationStyle.icon(note.kind))
                .font(DSFont.callout)
                .foregroundStyle(NotificationStyle.color(note.kind))
                .frame(width: 30, height: 30)
                .background(NotificationStyle.color(note.kind).opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(NotificationStyle.title(note.kind))
                    .font(DSFont.captionMedium)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: DSSpacing.sm)
            Text(note.date, style: .relative)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textTertiary)
        }
        .padding(.vertical, DSSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String? {
        let parts = [note.printerName, note.detail].compactMap(\.self).filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
