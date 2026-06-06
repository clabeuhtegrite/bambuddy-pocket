// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Écran racine : liste des serveurs Bambuddy configurés, avec ajout/édition et accès au détail.
struct ServerListView: View {
    @Bindable var model: ServerListModel
    @State private var presentedForm: ServerFormMode?
    @State private var showingAbout = false
    /// Serveur sélectionné : présente la coquille à onglets (`ServerHomeView`) en plein écran.
    @State private var selectedServer: ServerConfiguration?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let selectedServer, model.servers.contains(where: { $0.id == selectedServer.id }) {
                ServerHomeView(
                    model: model,
                    server: selectedServer,
                    onBackToServers: { self.selectedServer = nil },
                    onSelectServer: { self.selectedServer = $0 }
                )
                // L'identité dépend du serveur : recompose toute la coquille (et ses view-models)
                // à la bascule de serveur.
                .id(selectedServer.id)
            } else {
                serverChooser
            }
        }
        // Cycle de vie des sessions temps réel (B0) :
        // - à la bascule de serveur (ou retour à la liste), on coupe les centres des serveurs qui ne
        //   sont plus à l'écran → pas de fuite de WebSocket/poll en multi-serveurs ;
        // - en arrière-plan, on suspend **tout** ; au retour au premier plan, les centres du serveur
        //   sélectionné redémarrent à la demande (la coquille les redemande au `.task`).
        .onChange(of: selectedServer?.id) { _, newID in
            model.stopUnselectedCenters(keeping: newID)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                model.suspendAllCenters()
            case .active:
                // Retour au premier plan : on relance la session du serveur affiché (idempotent).
                model.resumeCenter(for: selectedServer?.id)
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    private var serverChooser: some View {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("About")
                }
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
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .onAppear { model.reload() }
        }
    }

    private var serverList: some View {
        List {
            ForEach(model.servers) { server in
                Button {
                    selectedServer = server
                } label: {
                    ServerRow(server: server)
                }
                .listRowBackground(DSColor.card)
            }
            .onDelete { offsets in
                try? model.delete(at: offsets)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
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
            Text(server.label)
                .font(DSFont.headline)
                .foregroundStyle(DSColor.textPrimary)
            HStack(spacing: DSSpacing.xs) {
                if server.isInsecureTransport {
                    Image(systemName: "lock.open")
                        .foregroundStyle(DSColor.statusWarning)
                        .accessibilityLabel(Text("Insecure connection (HTTP)"))
                }
                Text(server.baseURL.absoluteString)
                    .font(DSFont.callout)
                    .foregroundStyle(DSColor.textSecondary)
            }
        }
        .padding(.vertical, DSSpacing.xxs)
    }
}

#Preview {
    ServerListView(model: ServerListModel(environment: .inMemory()))
}
