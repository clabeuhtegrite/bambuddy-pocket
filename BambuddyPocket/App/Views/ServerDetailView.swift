// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import SwiftUI

/// Détail d'un serveur : informations de connexion, test (`GET /auth/status`), édition et
/// suppression. Reflète les éditions en relisant la configuration depuis le view-model.
struct ServerDetailView: View {
    let model: ServerListModel
    let server: ServerConfiguration

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
            deleteSection
        }
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
                        .foregroundStyle(.orange)
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
                        .foregroundStyle(.green)
                }
                .font(.footnote)
            case let .failure(message):
                Label {
                    Text("Connection failed: \(message)")
                } icon: {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                }
                .font(.footnote)
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
        ServerDetailView(
            model: ServerListModel(environment: .inMemory()),
            server: ServerConfiguration(
                label: "Atelier",
                baseURL: URL(string: "http://192.168.1.50:8000") ?? URL(filePath: "/")
            )
        )
    }
}
