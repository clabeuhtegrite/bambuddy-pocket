// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI
import UIKit

/// En-tête composite du détail imprimante (proposition B) : flux/rendu, strip de températures,
/// strip AMS coloré. Regroupé pour alléger `PrinterDetailView`.
struct PrinterDetailHero: View {
    let printer: Printer
    let model: PrinterListModel
    let status: PrinterStatus?
    let capabilities: PrinterCapabilities

    var body: some View {
        VStack(spacing: DSSpacing.sm) {
            PrinterFeedHero(printer: printer, model: model, status: status)
            PrinterTempStrip(status: status, capabilities: capabilities)
            if let units = status?.ams, !units.isEmpty {
                PrinterAMSStrip(units: units)
            }
        }
        // Rendu pleine largeur sous le titre, sans habillage de cellule de liste.
        .listRowInsets(EdgeInsets(
            top: DSSpacing.sm,
            leading: DSSpacing.md,
            bottom: DSSpacing.sm,
            trailing: DSSpacing.md
        ))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}

// MARK: - Hero (flux caméra / rendu)

/// En-tête plein cadre du détail imprimante (proposition B des maquettes) : flux caméra (snapshot
/// rafraîchi) ou rendu de repli, avec surimpression du nom, du badge « En direct », de la
/// progression et de contrôles en ligne (pause/reprise, lumière chambre) quand une impression
/// tourne.
struct PrinterFeedHero: View {
    let printer: Printer
    let model: PrinterListModel
    let status: PrinterStatus?

    @State private var image: UIImage?

    private var showsCamera: Bool {
        printer.capabilities.hasCamera && status?.ipcam != false
    }

    private var isPrinting: Bool {
        status?.isPrinting ?? false
    }

    var body: some View {
        ZStack {
            background
            overlays
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.large, style: .continuous)
                .strokeBorder(DSColor.border, lineWidth: DSBorder.thin)
        )
        .task(id: showsCamera) {
            if showsCamera { await snapshotLoop() }
        }
    }

    @ViewBuilder
    private var background: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityLabel("Live camera feed")
        } else {
            LinearGradient(
                colors: [DSColor.surfaceTertiary, DSColor.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(
                Image(systemName: "cube.transparent")
                    .font(.system(size: 48))
                    .foregroundStyle(DSColor.accent.opacity(0.8))
            )
            .accessibilityLabel(showsCamera ? "Connecting to camera" : "No camera")
        }
    }

    private var overlays: some View {
        VStack {
            topBar
            Spacer()
            if isPrinting { bottomBar }
        }
        .padding(DSSpacing.sm)
    }

    private var topBar: some View {
        HStack {
            Text(printer.name)
                .font(DSFont.headline)
                .foregroundStyle(.white)
                .shadow(radius: 3)
            Spacer()
            if showsCamera, image != nil {
                liveTag
            }
        }
    }

    private var liveTag: some View {
        HStack(spacing: DSSpacing.xs) {
            Circle().fill(DSColor.statusError).frame(width: 7, height: 7)
            Text("Live")
                .font(DSFont.captionMedium)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(.black.opacity(0.45), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var bottomBar: some View {
        HStack(alignment: .center, spacing: DSSpacing.sm) {
            percentLabel
            VStack(alignment: .leading, spacing: 1) {
                if let job = status?.subtaskName ?? status?.currentPrint {
                    Text(job)
                        .font(DSFont.captionMedium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(metaLine)
                    .font(DSFont.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
            Spacer(minLength: DSSpacing.sm)
            inlineControls
        }
        .padding(DSSpacing.sm)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        )
    }

    private var percentLabel: some View {
        HStack(alignment: .firstTextBaseline, spacing: 1) {
            Text("\(Int((status?.progress ?? 0).rounded()))")
                .font(DSFont.inter(24, weight: .bold, relativeTo: .title))
            Text("%").font(DSFont.caption)
        }
        .foregroundStyle(.white)
        .accessibilityLabel(Text("\(Int((status?.progress ?? 0).rounded()))%"))
    }

    private var metaLine: String {
        var parts: [String] = []
        if let layer = status?.layerNum, let total = status?.totalLayers, total > 0 {
            parts.append(String(localized: "layer \(layer)/\(total)"))
        }
        if let remaining = PrinterPresentation.remainingTime(minutes: status?.remainingTime) {
            parts.append(remaining)
        }
        return parts.joined(separator: " · ")
    }

    private var inlineControls: some View {
        HStack(spacing: DSSpacing.xs) {
            circleButton(
                systemImage: status?.state == .pause ? "play.fill" : "pause.fill",
                label: status?.state == .pause ? "Resume" : "Pause"
            ) {
                Task {
                    if status?.state == .pause {
                        await model.resume(printer)
                    } else {
                        await model.pause(printer)
                    }
                }
            }
            circleButton(
                systemImage: status?.chamberLight == true ? "lightbulb.fill" : "lightbulb",
                label: "Chamber light"
            ) {
                Task { await model.setChamberLight(printer, on: !(status?.chamberLight ?? false)) }
            }
        }
    }

    private func circleButton(
        systemImage: String,
        label: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(DSFont.callout)
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.18), in: Circle())
        }
        .accessibilityLabel(label)
    }

    /// Rafraîchit un snapshot caméra toutes les secondes (léger, sans MJPEG persistant côté détail).
    private func snapshotLoop() async {
        let token = await model.cameraStreamToken()
        while !Task.isCancelled {
            let data = await model.cameraSnapshot(for: printer, token: token)
            if let data, let decoded = UIImage(data: data) {
                image = decoded
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }
}

// MARK: - Strip de températures (buses / plateau / chambre)

/// Bandeau compact de mesures clés : buse(s), plateau, chambre. S'adapte aux capacités (deux buses
/// G/D sur double extrudeur exposant la donnée ; chambre seulement si rapportée).
struct PrinterTempStrip: View {
    let status: PrinterStatus?
    let capabilities: PrinterCapabilities

    private var temps: Temperatures? {
        status?.temperatures
    }

    private var showsSecondNozzle: Bool {
        status?.showsSecondNozzle(capabilities: capabilities) ?? false
    }

    var body: some View {
        // Cellules de largeur égale (`flex-1`) sur une seule rangée. Le contenu (libellé +
        // température) reste lisible : libellé tronqué proprement plutôt que de pousser la mise en
        // page. Réplique le strip web (`flex items-stretch gap-1.5`) avec des cellules `flex-1`.
        HStack(spacing: DSSpacing.sm) {
            if showsSecondNozzle {
                cell(label: "Nozzle L", current: temps?.nozzle, target: temps?.nozzleTarget)
                cell(label: "Nozzle R", current: temps?.nozzle2, target: temps?.nozzle2Target)
            } else {
                cell(label: "Nozzle", current: temps?.nozzle, target: temps?.nozzleTarget)
            }
            cell(label: "Bed", current: temps?.bed, target: temps?.bedTarget)
            if temps?.chamber != nil {
                cell(label: "Chamber", current: temps?.chamber, target: nil)
            }
        }
    }

    private func cell(label: LocalizedStringKey, current: Double?, target: Double?) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(DSFont.caption)
                .textCase(.uppercase)
                .foregroundStyle(DSColor.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value(current: current, target: target))
                .font(DSFont.bodyMedium)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.sm)
        .padding(.horizontal, DSSpacing.xs)
        .dsCardSurface()
        .accessibilityElement(children: .combine)
    }

    private func value(current: Double?, target: Double?) -> String {
        guard let target, target > 0 else {
            return PrinterPresentation.temperature(current)
        }
        return PrinterPresentation.temperaturePair(current, target)
    }
}

// MARK: - Strip AMS (bobines colorées)

/// Bandeau AMS visuel : anneaux colorés par bobine, type, couleur/niveau (niveau bas en ambre).
///
/// Mise en page inspirée du strip AMS de la web UI (`flex items-stretch gap-1.5 flex-wrap`,
/// bobines de **taille fixe**) : plutôt que d'écraser les bobines dans une rangée à largeur fixe
/// (chevauchement, anneaux coupés, libellés tronqués quand il y a plusieurs unités de 4 plateaux),
/// les bobines gardent une largeur fixe et la rangée **défile horizontalement**. Chaque unité AMS
/// est présentée comme un groupe distinct (en-tête + bobines), comme la web UI groupe par AMS.
struct PrinterAMSStrip: View {
    let units: [AMSUnit]

    private var loadedCount: Int {
        units.reduce(0) { sum, unit in
            sum + (unit.tray ?? []).count { ($0.trayType?.isEmpty == false) }
        }
    }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                header
                // Défilement horizontal : les bobines conservent leur taille (pas d'écrasement) même
                // avec plusieurs unités AMS. Les groupes par unité sont séparés visuellement.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: DSSpacing.md) {
                        ForEach(units) { unit in
                            unitGroup(unit)
                        }
                    }
                }
            }
        }
    }

    /// Un groupe = une unité AMS : libellé d'unité (+ humidité si rapportée) puis ses bobines.
    private func unitGroup(_ unit: AMSUnit) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(spacing: DSSpacing.xs) {
                Text(unitLabel(unit))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                if let humidity = unit.humidity {
                    Text("\(humidity)%")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textMuted)
                }
            }
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                ForEach(unit.tray ?? []) { tray in
                    SpoolView(tray: tray)
                }
            }
        }
    }

    /// Libellé court d'une unité (l'AMS-HT a des id ≥ 128 ; sinon 1-based).
    private func unitLabel(_ unit: AMSUnit) -> String {
        if unit.id >= 128 {
            return String(localized: "AMS-HT \(unit.id - 128 + 1)")
        }
        return String(localized: "AMS \(unit.id + 1)")
    }

    private var header: some View {
        HStack {
            Text("AMS")
                .font(DSFont.captionMedium)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            Text("\(loadedCount) spools")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Représentation visuelle d'une bobine : anneau coloré + type + couleur/niveau. Largeur **fixe**
/// pour éviter l'écrasement quand la rangée contient beaucoup de bobines (défilement horizontal).
private struct SpoolView: View {
    let tray: AMSTray

    /// Largeur fixe d'une bobine (anneau + libellé), suffisante pour un type de filament court.
    private static let width: CGFloat = 56

    private var isLow: Bool {
        (tray.remain ?? 100) <= 10 && isLoaded
    }

    private var isLoaded: Bool {
        tray.trayType?.isEmpty == false
    }

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            ZStack {
                Circle()
                    .strokeBorder(ringColor, lineWidth: 4)
                    .frame(width: 44, height: 44)
                Circle()
                    .fill(DSColor.card)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().strokeBorder(DSColor.border, lineWidth: DSBorder.thin))
            }
            Text(typeLabel)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.8)
            if let remain = tray.remain, isLoaded {
                Text("\(remain)%")
                    .font(DSFont.caption)
                    .foregroundStyle(isLow ? DSColor.statusWarning : DSColor.textSecondary)
            }
        }
        .frame(width: Self.width)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var ringColor: Color {
        PrinterPresentation.color(hexRGBA: tray.trayColor) ?? DSColor.border
    }

    private var typeLabel: String {
        if let type = tray.trayType, !type.isEmpty { return type }
        return String(localized: "Empty")
    }

    private var accessibilityText: String {
        guard isLoaded else { return String(localized: "Empty slot") }
        if let remain = tray.remain {
            return "\(typeLabel) · \(remain)%"
        }
        return typeLabel
    }
}
