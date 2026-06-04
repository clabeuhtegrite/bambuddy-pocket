// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Prises connectées : liste avec état temps réel et pilotage de l'alimentation (on/off).
struct SmartPlugsView: View {
    @State private var model: SmartPlugsModel

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeSmartPlugsModel(for: server))
    }

    var body: some View {
        List {
            ForEach(model.plugs) { plug in
                SmartPlugRow(
                    plug: plug,
                    status: model.statuses[plug.id],
                    isBusy: model.busy.contains(plug.id),
                    onAction: { action in
                        Task { await model.control(plug, action: action) }
                    }
                )
                .listRowBackground(DSColor.card)
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Smart plugs")
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
        if !model.hasLoaded, model.plugs.isEmpty {
            ProgressView().tint(DSColor.accent)
        } else if model.plugs.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load smart plugs", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No smart plugs",
                    systemImage: "powerplug",
                    description: Text("No smart plug is configured on this server.")
                )
            }
        }
    }
}

private struct SmartPlugRow: View {
    let plug: SmartPlug
    let status: SmartPlugStatus?
    let isBusy: Bool
    let onAction: (SmartPlugAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(plug.name)
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                Spacer()
                DSStatusBadge(stateText, intent: stateIntent)
            }
            powerControls
            if let power = status?.energy?.power {
                Text(verbatim: String(format: "%.1f W", power))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }

    @ViewBuilder
    private var powerControls: some View {
        if isBusy {
            ProgressView().tint(DSColor.accent)
        } else {
            HStack(spacing: DSSpacing.sm) {
                Button {
                    onAction(.on)
                } label: {
                    Label("On", systemImage: "power")
                }
                .buttonStyle(.dsSecondary)
                .disabled(status?.isReachable == false)
                Button {
                    onAction(.off)
                } label: {
                    Label("Off", systemImage: "poweroff")
                }
                .buttonStyle(.dsSecondary)
                .disabled(status?.isReachable == false)
            }
        }
    }

    private var subtitle: String {
        if let type = plug.plugType {
            return type.capitalized
        }
        return String(localized: "Smart plug")
    }

    private var stateText: String {
        guard let status, status.isReachable else {
            return String(localized: "Unreachable")
        }
        switch status.isOn {
        case true?: return String(localized: "On")
        case false?: return String(localized: "Off")
        default: return String(localized: "Unknown")
        }
    }

    private var stateIntent: DSStatusIntent {
        guard let status, status.isReachable else {
            return .neutral
        }
        switch status.isOn {
        case true?: return .success
        case false?: return .neutral
        default: return .warning
        }
    }
}
