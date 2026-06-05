// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Section d'une unité AMS, **adaptative au type d'AMS** (standard / AMS Lite / AMS-HT).
///
/// - En-tête : nom localisé incluant le type (« AMS 1 », « AMS Lite », « AMS-HT 1 »).
/// - Humidité / température : affichées seulement si rapportées (AMS Lite ouverte n'en a pas).
/// - Séchage : proposé uniquement pour les unités qui le prennent en charge (standard `n3f`/`ams`
///   et HT `n3s` ; l'AMS Lite ne sèche pas — cf. amont `print_scheduler` : seuls n3f/n3s sèchent).
/// - Plateaux : 1 slot pour l'AMS-HT, jusqu'à 4 pour standard/Lite ; slots vides affichés « Empty ».
struct AMSUnitSection: View {
    let unit: AMSUnit
    let capabilities: PrinterCapabilities
    let printer: Printer
    let model: PrinterListModel

    /// Type résolu de l'unité (statut prioritaire, modèle en repli pour distinguer l'AMS Lite).
    private var kind: AMSKind {
        unit.resolvedKind(modelOnlySupportsLite: capabilities.amsOnlyLite)
    }

    /// Le séchage est-il pertinent pour cette unité ? Standard et HT seulement (pas l'AMS Lite).
    private var supportsDrying: Bool {
        kind != .amsLite
    }

    var body: some View {
        Section {
            climateRow
            ForEach(unit.tray ?? []) { tray in
                TrayRow(tray: tray)
                    .swipeActions(edge: .leading) {
                        Button("Load") {
                            Task { await model.loadFilament(printer, trayID: trayIndex(tray)) }
                        }
                        .tint(DSColor.accent)
                    }
            }
            if supportsDrying {
                dryingButton
            }
        } header: {
            Text(AMSPresentation.title(kind: kind, id: unit.id))
        }
    }

    /// Humidité et température, seulement si rapportées par l'unité (AMS Lite : souvent absentes).
    @ViewBuilder
    private var climateRow: some View {
        if let humidity = unit.humidity {
            LabeledContent("Humidity", value: "\(humidity)%")
        }
        if let temp = unit.temp {
            LabeledContent("AMS temperature", value: PrinterPresentation.temperature(temp))
        }
    }

    @ViewBuilder
    private var dryingButton: some View {
        if (unit.dryStatus ?? 0) > 0 {
            Button("Stop drying") {
                Task { await model.stopDrying(printer, amsID: unit.id) }
            }
        } else {
            Button("Start drying") {
                Task { await model.startDrying(printer, amsID: unit.id) }
            }
        }
    }

    /// Identifiant de plateau global (`ams_id * 4 + slot`) attendu par `POST /ams/load`.
    private func trayIndex(_ tray: AMSTray) -> Int {
        unit.id * 4 + tray.id
    }
}

/// Ligne d'un slot AMS : pastille de couleur, type de filament et niveau restant.
struct TrayRow: View {
    let tray: AMSTray

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Circle()
                .fill(PrinterPresentation.color(hexRGBA: tray.trayColor) ?? .secondary)
                .frame(width: 16, height: 16)
                .overlay(Circle().strokeBorder(.quaternary))
            VStack(alignment: .leading, spacing: 1) {
                Text(displayType)
                // Nom de couleur dérivé (toujours présent quand un filament est chargé, #8).
                if isLoaded, let colorName {
                    Text(colorName)
                        .font(DSFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let remain = tray.remain {
                Text("\(remain)%")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isLoaded: Bool {
        tray.trayType?.isEmpty == false
    }

    /// Nom de couleur lisible, dérivé du hex si le slot est chargé.
    private var colorName: String? {
        FilamentColorName.from(hex: tray.trayColor)
    }

    /// Type de filament, ou « Empty » pour un slot vide (type nil **ou** chaîne vide).
    private var displayType: String {
        if let type = tray.trayType, !type.isEmpty {
            return type
        }
        return String(localized: "Empty")
    }
}

/// Libellés localisés pour l'affichage des unités AMS.
enum AMSPresentation {
    /// Titre de section d'une unité selon son type. L'AMS-HT et la standard sont numérotées ;
    /// l'AMS Lite (une seule par A1) ne l'est pas.
    static func title(kind: AMSKind, id: Int) -> String {
        switch kind {
        case .amsLite:
            String(localized: "AMS Lite")
        case .ht:
            // Les AMS-HT ont des id matériels ≥ 128 ; on présente un numéro lisible (1-based).
            String(localized: "AMS-HT \(htDisplayNumber(id))")
        case .standard:
            String(localized: "AMS \(id + 1)")
        }
    }

    /// Numéro lisible (1-based) d'une AMS-HT dont l'id matériel commence à 128.
    private static func htDisplayNumber(_ id: Int) -> Int {
        id >= 128 ? id - 128 + 1 : id + 1
    }
}
