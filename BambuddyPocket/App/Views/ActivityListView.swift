// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import Foundation
import SwiftUI

/// Flux d'activité d'un serveur (historique des notifications émises).
struct ActivityListView: View {
    @State private var model: ActivityListModel
    @State private var query = ""

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeActivityListModel(for: server))
    }

    private var filtered: [ActivityEntry] {
        guard !query.isEmpty else {
            return model.entries
        }
        return model.entries.filter {
            $0.title.localizedCaseInsensitiveContains(query)
                || $0.message.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        List {
            ForEach(filtered) { entry in
                ActivityRow(entry: entry)
            }
        }
        .searchable(text: $query)
        .overlay { placeholder }
        .navigationTitle("Activity")
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
        if !model.hasLoaded, model.entries.isEmpty {
            ProgressView()
        } else if model.entries.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load activity", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No activity",
                    systemImage: "bell.slash",
                    description: Text("No activity yet.")
                )
            }
        }
    }
}

/// Ligne d'activité : succès/échec, titre, message, imprimante et date.
private struct ActivityRow: View {
    let entry: ActivityEntry

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: entry.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(entry.success ? .green : .red)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(entry.title)
                    .font(.headline)
                Text(entry.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                HStack(spacing: DSSpacing.sm) {
                    if let printer = entry.printerName {
                        Text(printer)
                    }
                    if let date = ArchivePresentation.date(entry.createdAt) {
                        Text(date)
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, DSSpacing.xs)
    }
}
