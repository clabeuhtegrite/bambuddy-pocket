// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Maintenance : vue d'ensemble par imprimante, échéances et action « marquer effectué ».
struct MaintenanceView: View {
    @State private var model: MaintenanceModel

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeMaintenanceModel(for: server))
    }

    var body: some View {
        List {
            ForEach(model.overview) { printer in
                Section {
                    ForEach(printer.maintenanceItems ?? []) { item in
                        MaintenanceItemRow(
                            item: item,
                            isBusy: model.busy.contains(item.id),
                            onPerform: { Task { await model.markPerformed(item) } }
                        )
                        .listRowBackground(DSColor.card)
                    }
                } header: {
                    MaintenanceSectionHeader(
                        name: printer.printerName ?? String(localized: "Printer"),
                        rodType: printer.rodType
                    )
                }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Maintenance")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.overview.isEmpty {
            ProgressView().tint(DSColor.accent)
        } else if model.overview.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load maintenance", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No maintenance",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("No maintenance items are tracked for this server.")
                )
            }
        }
    }
}

/// En-tête de section : nom de l'imprimante + type de rails/tiges (contexte de maintenance des
/// axes). Le type de rails est masqué pour un modèle inconnu (`rodType == nil`).
private struct MaintenanceSectionHeader: View {
    let name: String
    let rodType: RodType?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
            if let rodType, let label = MaintenancePresentation.rodTypeLabel(rodType) {
                Text(label)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .textCase(nil)
                    .accessibilityLabel(Text("Motion system: \(label)"))
            }
        }
    }
}

/// Libellés localisés propres à la maintenance.
enum MaintenancePresentation {
    /// Libellé lisible du type de rails/tiges, ou `nil` si inconnu.
    static func rodTypeLabel(_ rodType: RodType) -> String? {
        switch rodType {
        case .carbon:
            String(localized: "Carbon rods")
        case .steelRod:
            String(localized: "Steel rods")
        case .linearRail:
            String(localized: "Linear rails")
        }
    }
}

private struct MaintenanceItemRow: View {
    let item: MaintenanceItem
    let isBusy: Bool
    let onPerform: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                Text(item.maintenanceTypeName ?? String(localized: "Maintenance"))
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                DSStatusBadge(statusText, intent: statusIntent)
            }
            Text(scheduleText)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
            if isBusy {
                ProgressView().tint(DSColor.accent)
            } else {
                Button {
                    onPerform()
                } label: {
                    Label("Mark performed", systemImage: "checkmark.circle")
                }
                .buttonStyle(.dsSecondary)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }

    private var statusText: String {
        if item.isDueNow {
            return String(localized: "Due")
        }
        if item.isWarningNow {
            return String(localized: "Soon")
        }
        return String(localized: "OK")
    }

    private var statusIntent: DSStatusIntent {
        if item.isDueNow {
            return .error
        }
        if item.isWarningNow {
            return .warning
        }
        return .success
    }

    private var scheduleText: String {
        if let hours = item.hoursUntilDue {
            let rounded = Int(hours.rounded())
            if rounded <= 0 {
                return String(localized: "Overdue by \(-rounded) h")
            }
            return String(localized: "Due in \(rounded) h")
        }
        if let interval = item.intervalHours {
            return String(localized: "Every \(Int(interval)) h")
        }
        return String(localized: "No schedule")
    }
}
