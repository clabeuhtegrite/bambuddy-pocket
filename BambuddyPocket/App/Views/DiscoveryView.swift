// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Découverte réseau : recherche d'imprimantes (SSDP) sur les sous-réseaux du serveur.
struct DiscoveryView: View {
    @State private var model: DiscoveryModel

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeDiscoveryModel(for: server))
    }

    var body: some View {
        List {
            controlSection
            if let info = model.info {
                infoSection(info)
            }
            printersSection
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Discovery")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await model.refreshPrinters() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    private var controlSection: some View {
        Section {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: model
                    .isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundStyle(model.isRunning ? DSColor.statusOK : DSColor.textSecondary)
                Text(model.isRunning ? "Discovery running" : "Discovery stopped")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
            Button {
                Task { await model.toggle() }
            } label: {
                if model.isRunning {
                    Label("Stop discovery", systemImage: "stop.circle")
                } else {
                    Label("Start discovery", systemImage: "play.circle")
                }
            }
        }
    }

    private func infoSection(_ info: DiscoveryInfo) -> some View {
        Section("Network") {
            if let subnets = info.subnets, !subnets.isEmpty {
                LabeledContent("Subnets", value: subnets.joined(separator: ", "))
            }
            if let docker = info.isDocker {
                LabeledContent("Containerized", value: docker ? String(localized: "Yes") : String(localized: "No"))
            }
        }
    }

    @ViewBuilder
    private var printersSection: some View {
        if model.printers.isEmpty {
            Section("Discovered printers") {
                Text("No printers found yet.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
            }
        } else {
            Section("Discovered printers") {
                ForEach(model.printers) { printer in
                    DiscoveredPrinterRow(printer: printer)
                        .listRowBackground(DSColor.card)
                }
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.info == nil {
            ProgressView().tint(DSColor.accent)
        } else if model.info == nil, model.printers.isEmpty, let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t load discovery", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        }
    }
}

private struct DiscoveredPrinterRow: View {
    let printer: DiscoveredPrinter

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(printer.name ?? printer.serial ?? String(localized: "Printer"))
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
            HStack(spacing: DSSpacing.sm) {
                if let model = printer.model {
                    Text(model)
                }
                if let ip = printer.ipAddress {
                    Text(ip).font(.caption.monospaced())
                }
            }
            .font(DSFont.caption)
            .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
