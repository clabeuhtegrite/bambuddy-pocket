// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Informations et gestion de connexion d'un serveur : détails, test (`GET /auth/status`),
/// édition, suppression et **bascule vers un autre serveur**. Accessible depuis « Plus → Serveur ».
/// Reprend la logique de l'ancien détail serveur sans le mur de menus (désormais réparti en
/// onglets / dans « Plus »).
struct ServerInfoView: View {
    let model: ServerListModel
    let server: ServerConfiguration

    /// Callback optionnel pour basculer vers un autre serveur (revient à la liste de serveurs).
    var onSelectServer: ((ServerConfiguration) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var testState: ConnectionTestState = .idle
    @State private var isEditing = false
    @State private var confirmingDelete = false

    /// Configuration à jour (relue après une édition), repli sur la valeur initiale.
    private var current: ServerConfiguration {
        model.servers.first { $0.id == server.id } ?? server
    }

    var body: some View {
        List {
            connectionSection
            testSection
            switchServerSection
            deleteSection
        }
        .dsListBackground()
        .navigationTitle(current.label)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            ServerEditView(model: model, mode: .edit(current))
        }
        .confirmationDialog(
            "Delete this server?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                try? model.delete(current)
                dismiss()
            }
        } message: {
            Text("Its stored credentials will be removed from this device.")
        }
    }

    private var connectionSection: some View {
        Section("Connection") {
            LabeledContent("URL", value: current.baseURL.absoluteString)
            LabeledContent("Authentication", value: authMethodLabel)
            if current.usesCloudflareAccess {
                LabeledContent("Cloudflare Access", value: String(localized: "Enabled"))
            }
            if current.isInsecureTransport {
                Label {
                    Text("Connection is not encrypted (HTTP).")
                } icon: {
                    Image(systemName: "lock.open")
                        .foregroundStyle(DSColor.statusWarning)
                }
                .font(.footnote)
            }
        }
    }

    private var testSection: some View {
        Section("Connection test") {
            Button {
                runTest()
            } label: {
                HStack {
                    Text("Test connection")
                    Spacer()
                    if case .testing = testState {
                        ProgressView()
                    }
                }
            }
            .disabled(testState == .testing)

            switch testState {
            case .idle, .testing:
                EmptyView()
            case let .success(status):
                let successKey: LocalizedStringKey = status.authEnabled
                    ? "Connected. Authentication is enabled on this server."
                    : "Connected. Authentication is disabled on this server."
                Label {
                    Text(successKey)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DSColor.statusOK)
                }
                .font(.footnote)
            case let .failure(message):
                Label {
                    Text("Connection failed: \(message)")
                } icon: {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(DSColor.statusError)
                }
                .font(.footnote)
            }
        }
    }

    /// Bascule vers un autre serveur configuré (multi-serveurs), si un callback est fourni et qu'au
    /// moins un autre serveur existe.
    @ViewBuilder
    private var switchServerSection: some View {
        let others = model.servers.filter { $0.id != current.id }
        if let onSelectServer, !others.isEmpty {
            Section("Switch server") {
                ForEach(others) { other in
                    Button {
                        onSelectServer(other)
                    } label: {
                        Label {
                            Text(other.label)
                                .foregroundStyle(DSColor.textPrimary)
                        } icon: {
                            Image(systemName: "arrow.left.arrow.right.circle")
                        }
                    }
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete server", role: .destructive) {
                confirmingDelete = true
            }
        }
    }

    private var authMethodLabel: String {
        switch current.authMethod {
        case .none: String(localized: "None")
        case .apiKey: String(localized: "API key")
        case .userPassword: String(localized: "Username & password")
        }
    }

    private func runTest() {
        testState = .testing
        let configuration = current
        Task {
            testState = await model.testConnection(configuration)
        }
    }
}

#Preview {
    NavigationStack {
        ServerInfoView(
            model: ServerListModel(environment: .inMemory()),
            server: ServerConfiguration(
                label: "Atelier",
                baseURL: URL(string: "http://192.168.1.50:8000") ?? URL(filePath: "/")
            )
        )
    }
}
