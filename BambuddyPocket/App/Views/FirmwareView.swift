// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Mises à jour firmware (lecture seule) : version courante vs dernière par imprimante, avec
/// les notes de version quand une mise à jour est disponible.
struct FirmwareView: View {
    @State private var model: FirmwareModel

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeFirmwareModel(for: server))
    }

    var body: some View {
        List {
            ForEach(model.updates) { update in
                Section {
                    FirmwareRow(update: update)
                        .listRowBackground(DSColor.card)
                    if update.isUpdateAvailable, let notes = update.releaseNotes, !notes.isEmpty {
                        NavigationLink {
                            FirmwareNotesView(title: update.latestVersion, notes: notes)
                        } label: {
                            Label("Release notes", systemImage: "doc.text")
                        }
                        .listRowBackground(DSColor.card)
                    }
                } header: {
                    Text(update.printerName ?? String(localized: "Printer"))
                }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Firmware")
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
        if !model.hasLoaded, model.updates.isEmpty {
            ProgressView().tint(DSColor.accent)
        } else if model.updates.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load firmware", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No firmware information",
                    systemImage: "cpu",
                    description: Text("No firmware update information is available.")
                )
            }
        }
    }
}

private struct FirmwareRow: View {
    let update: FirmwareUpdate

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack {
                if let model = update.model {
                    Text(model)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.textSecondary)
                }
                Spacer()
                DSStatusBadge(
                    update.isUpdateAvailable ? String(localized: "Update available") : String(localized: "Up to date"),
                    intent: update.isUpdateAvailable ? .warning : .success
                )
            }
            if let current = update.currentVersion {
                LabeledContent("Current") {
                    Text(current).font(.callout.monospaced())
                }
            }
            if update.isUpdateAvailable, let latest = update.latestVersion {
                LabeledContent("Latest") {
                    Text(latest).font(.callout.monospaced()).foregroundStyle(DSColor.accent)
                }
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }
}

/// Affichage des notes de version d'un firmware.
private struct FirmwareNotesView: View {
    let title: String?
    let notes: String

    var body: some View {
        ScrollView {
            Text(notes)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DSSpacing.md)
        }
        .background(DSColor.background)
        .navigationTitle(title ?? String(localized: "Release notes"))
        .toolbarTitleDisplayMode(.inline)
    }
}
