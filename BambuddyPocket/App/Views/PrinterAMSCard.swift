// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Carte d'une **unité AMS**, calquée sur la web UI (`PrintersPage.tsx`, bloc « Filaments ») :
/// une **unité par carte**, en-tête (libellé + humidité/température + séchage), puis une **grille
/// de slots** (cercle coloré numéroté, type, nom de couleur, barre de remplissage, %).
///
/// - Standard / AMS Lite : 4 slots affichés (slots vides inclus, atténués).
/// - AMS-HT : 1 slot.
/// Le séchage n'est proposé que pour les unités qui le supportent (standard `n3f` / HT `n3s`),
/// jamais pour l'AMS Lite — aligné sur l'amont (`print_scheduler`).
struct PrinterAMSCard: View {
    let unit: AMSUnit
    let capabilities: PrinterCapabilities
    let printer: Printer
    let model: PrinterListModel

    /// Type résolu de l'unité (statut prioritaire, modèle en repli pour distinguer l'AMS Lite).
    private var kind: AMSKind {
        unit.resolvedKind(modelOnlySupportsLite: capabilities.amsOnlyLite)
    }

    private var supportsDrying: Bool {
        kind != .amsLite
    }

    /// Nombre de slots à afficher : 1 pour l'AMS-HT, 4 sinon (slots vides inclus).
    private var slotCount: Int {
        kind == .ht ? 1 : 4
    }

    /// Le séchage est-il en cours (chrono > 0) ?
    private var isDrying: Bool {
        (unit.dryStatus ?? 0) > 0 || (unit.dryTime ?? 0) > 0
    }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                header
                if isDrying {
                    dryingBar
                }
                slotsGrid
            }
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: En-tête

    private var header: some View {
        HStack(alignment: .center, spacing: DSSpacing.sm) {
            Text(AMSPresentation.title(kind: kind, id: unit.id))
                .font(DSFont.captionMedium)
                .foregroundStyle(DSColor.textPrimary)
            Spacer(minLength: DSSpacing.sm)
            HStack(spacing: DSSpacing.sm) {
                if let humidity = unit.humidity {
                    AMSClimateChip(
                        systemImage: "humidity",
                        value: "\(humidity)%",
                        tint: humidityTint(humidity)
                    )
                    .accessibilityLabel(Text("Humidity \(humidity)%"))
                }
                if let temp = unit.temp {
                    AMSClimateChip(
                        systemImage: "thermometer.medium",
                        value: PrinterPresentation.temperature(temp),
                        tint: temperatureTint(temp)
                    )
                    .accessibilityLabel(Text("AMS temperature \(PrinterPresentation.temperature(temp))"))
                }
                if supportsDrying {
                    dryingButton
                }
            }
        }
    }

    @ViewBuilder
    private var dryingButton: some View {
        if model.isRunning(.drying, for: printer) {
            ProgressView().controlSize(.small)
        } else if isDrying {
            Button {
                Task { await model.stopDrying(printer, amsID: unit.id) }
            } label: {
                Image(systemName: "flame.fill")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.statusWarning)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop drying")
        } else {
            Button {
                Task { await model.startDrying(printer, amsID: unit.id) }
            } label: {
                Image(systemName: "flame")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start drying")
        }
    }

    private var dryingBar: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: "flame.fill")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.statusWarning)
            Text("Drying")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.statusWarning)
            if let minutes = unit.dryTime, minutes > 0 {
                Text(dryingRemaining(minutes))
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, DSSpacing.sm)
        .padding(.vertical, DSSpacing.xs)
        .background(DSColor.statusWarning.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Slots

    private var slotsGrid: some View {
        let columns = Array(
            repeating: GridItem(.flexible(), spacing: DSSpacing.xs),
            count: slotCount
        )
        return LazyVGrid(columns: columns, spacing: DSSpacing.xs) {
            ForEach(0 ..< slotCount, id: \.self) { slotIndex in
                AMSSlotView(
                    tray: tray(at: slotIndex),
                    slotNumber: slotIndex + 1
                )
                .swipeActionLoadable {
                    Task { await model.loadFilament(printer, trayID: unit.id * 4 + slotIndex) }
                }
            }
        }
    }

    /// Plateau correspondant à un index de slot (via `id`, sinon position dans le tableau).
    private func tray(at index: Int) -> AMSTray? {
        let trays = unit.tray ?? []
        if let match = trays.first(where: { $0.id == index }) {
            return match
        }
        return index < trays.count ? trays[index] : nil
    }

    // MARK: Climat (seuils web)

    /// Humidité : ≤ good vert, ≤ fair ambre, sinon rouge (seuils amont 40 / 60).
    private func humidityTint(_ value: Int) -> Color {
        switch value {
        case ...40: DSColor.statusOK
        case ...60: DSColor.statusWarning
        default: DSColor.statusError
        }
    }

    /// Température AMS : ≤ good vert, ≤ fair ambre, sinon rouge (seuils amont 28 / 35).
    private func temperatureTint(_ value: Double) -> Color {
        switch value {
        case ...28: DSColor.statusOK
        case ...35: DSColor.statusWarning
        default: DSColor.statusError
        }
    }

    private func dryingRemaining(_ minutes: Int) -> String {
        if minutes >= 60 {
            return String(localized: "\(minutes / 60) h \(minutes % 60) min left")
        }
        return String(localized: "\(minutes) min left")
    }
}

/// Pastille climat (humidité / température) avec icône et valeur teintées selon le seuil.
private struct AMSClimateChip: View {
    let systemImage: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(DSFont.inter(10, relativeTo: .caption2))
                .accessibilityHidden(true)
            Text(value)
                .font(DSFont.caption)
        }
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
    }
}

/// Un slot AMS : cercle de couleur numéroté, type de filament, nom de couleur et barre de
/// remplissage avec pourcentage. Slot vide : cercle atténué et libellé « Empty ».
struct AMSSlotView: View {
    let tray: AMSTray?
    let slotNumber: Int

    private var isLoaded: Bool {
        tray?.trayType?.isEmpty == false
    }

    private var fill: Int? {
        guard isLoaded, let remain = tray?.remain, remain >= 0 else { return nil }
        return remain
    }

    private var isLow: Bool {
        (fill ?? 100) <= 10
    }

    var body: some View {
        VStack(spacing: DSSpacing.xs) {
            circle
            Text(typeLabel)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if isLoaded, let colorName {
                Text(colorName)
                    .font(DSFont.inter(10, relativeTo: .caption2))
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            fillBar
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DSSpacing.xs)
        .padding(.horizontal, DSSpacing.xxs)
        .background(DSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.small, style: .continuous)
                .strokeBorder(DSColor.border, lineWidth: DSBorder.thin)
        )
        .opacity(isLoaded ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var circle: some View {
        ZStack {
            Circle()
                .fill(PrinterPresentation.color(hexRGBA: tray?.trayColor) ?? DSColor.surfaceTertiary)
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(DSColor.border, lineWidth: DSBorder.thin))
            Text("\(slotNumber)")
                .font(DSFont.inter(11, weight: .bold, relativeTo: .caption2))
                .foregroundStyle(slotNumberColor)
                .minimumScaleFactor(0.7)
        }
    }

    /// Numéro lisible sur n'importe quelle couleur de fond (contraste selon la luminance).
    private var slotNumberColor: Color {
        guard isLoaded, let hex = tray?.trayColor else { return DSColor.textSecondary }
        return PrinterPresentation.isLightColor(hexRGBA: hex) ? .black : .white
    }

    @ViewBuilder
    private var fillBar: some View {
        if let fill {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(DSColor.surfaceTertiary)
                    Capsule()
                        .fill(isLow ? DSColor.statusWarning : DSColor.accent)
                        .frame(width: proxy.size.width * CGFloat(fill) / 100)
                }
            }
            .frame(height: 4)
            Text("\(fill)%")
                .font(DSFont.inter(10, relativeTo: .caption2))
                .foregroundStyle(isLow ? DSColor.statusWarning : DSColor.textSecondary)
        } else {
            // Réserve la même hauteur pour aligner les slots vides sur les slots chargés.
            Color.clear.frame(height: 4)
        }
    }

    private var typeLabel: String {
        if let type = tray?.trayType, !type.isEmpty { return type }
        return String(localized: "Empty")
    }

    private var colorName: String? {
        FilamentColorName.from(hex: tray?.trayColor)
    }

    private var accessibilityText: String {
        guard isLoaded else { return String(localized: "Slot \(slotNumber): empty") }
        var parts = [typeLabel]
        if let colorName { parts.append(colorName) }
        if let fill { parts.append("\(fill)%") }
        return String(localized: "Slot \(slotNumber): \(parts.joined(separator: ", "))")
    }
}

private extension View {
    /// Action « Charger » au glissement (réservée aux vues de slot non vides).
    func swipeActionLoadable(_ action: @escaping () -> Void) -> some View {
        contextMenu {
            Button {
                action()
            } label: {
                Label("Load", systemImage: "tray.and.arrow.down")
            }
        }
    }
}
