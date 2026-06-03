// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Écran racine : liste des serveurs Bambuddy configurés, avec ajout/édition et accès au détail.
struct ServerListView: View {
    @Bindable var model: ServerListModel
    @State private var presentedForm: ServerFormMode?

    var body: some View {
        NavigationStack {
            Group {
                if model.servers.isEmpty {
                    emptyState
                } else {
                    serverList
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        presentedForm = .add
                    } label: {
                        Label("Add server", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $presentedForm) { mode in
                ServerEditView(model: model, mode: mode)
            }
            .onAppear { model.reload() }
        }
    }

    private var serverList: some View {
        List {
            ForEach(model.servers) { server in
                NavigationLink(value: server) {
                    ServerRow(server: server)
                }
            }
            .onDelete { offsets in
                try? model.delete(at: offsets)
            }
        }
        .navigationDestination(for: ServerConfiguration.self) { server in
            ServerDetailView(model: model, server: server)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No servers", systemImage: "server.rack")
        } description: {
            Text("Add a Bambuddy server to get started.")
        } actions: {
            Button("Add server") { presentedForm = .add }
                .buttonStyle(.borderedProminent)
        }
        .padding(DSSpacing.lg)
    }
}

/// Ligne de la liste des serveurs : libellé, URL et indicateur de transport en clair.
private struct ServerRow: View {
    let server: ServerConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(server.label).font(.headline)
            HStack(spacing: DSSpacing.xs) {
                if server.isInsecureTransport {
                    Image(systemName: "lock.open")
                        .foregroundStyle(.orange)
                        .accessibilityLabel(Text("Insecure connection (HTTP)"))
                }
                Text(server.baseURL.absoluteString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    ServerListView(model: ServerListModel(environment: .inMemory()))
}
