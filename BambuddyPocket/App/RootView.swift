// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Écran racine (placeholder Phase 0). La liste des serveurs et leur ajout seront
/// implémentés dans un prochain incrément de la Phase 0 (gestion multi-serveurs + Keychain).
struct RootView: View {
    @State private var servers: [ServerConfiguration] = []
    @State private var showingAddServer = false

    var body: some View {
        NavigationStack {
            Group {
                if servers.isEmpty {
                    emptyState
                } else {
                    List(servers) { server in
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            Text(server.label).font(.headline)
                            Text(server.baseURL.absoluteString)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddServer = true
                    } label: {
                        Label("Add server", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddServer) {
                placeholderSheet
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No servers", systemImage: "server.rack")
        } description: {
            Text("Add a Bambuddy server to get started.")
        } actions: {
            Button("Add server") { showingAddServer = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(DSSpacing.lg)
    }

    private var placeholderSheet: some View {
        NavigationStack {
            ContentUnavailableView(
                "Coming soon",
                systemImage: "hammer",
                description: Text("Server management arrives in the next milestone.")
            )
            .navigationTitle("Add server")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showingAddServer = false }
                }
            }
        }
    }
}

#Preview {
    RootView()
}
