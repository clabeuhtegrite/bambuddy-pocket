// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
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
    @State private var showingNotifications = false

    /// Configuration à jour (relue après une édition), repli sur la valeur initiale.
    private var current: ServerConfiguration {
        model.servers.first { $0.id == server.id } ?? server
    }

    /// Centre de notifications persistant du serveur (session WebSocket vivante).
    private var notificationCenter: ServerNotificationCenter {
        model.notificationCenter(for: current)
    }

    var body: some View {
        List {
            operationsSection
            administrationSection
            connectionSection
            testSection
            deleteSection
        }
        .scrollContentBackground(.hidden)
        .background(DSColor.background)
        .navigationTitle(current.label)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NotificationsToolbarButton(center: notificationCenter) {
                    showingNotifications = true
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
        }
        .overlay(alignment: .top) {
            NotificationBanner(center: notificationCenter) {
                showingNotifications = true
            }
        }
        .sheet(isPresented: $showingNotifications) {
            NotificationsView(center: notificationCenter)
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

    /// Section « exploitation » : écrans d'usage courant (impression, inventaire, bibliothèque…).
    private var operationsSection: some View {
        Section {
            link("Printers", "printer") { PrinterListView(server: current, serverList: model) }
            link("Print queue", "list.number") { QueueListView(server: current, serverList: model) }
            link("Print history", "clock.arrow.circlepath") { ArchiveListView(server: current, serverList: model) }
            link("Print log", "doc.text.below.ecg") { PrintLogView(server: current, serverList: model) }
            link("Activity", "bell") { ActivityListView(server: current, serverList: model) }
            link("Filaments", "circle.dashed") { InventoryListView(server: current, serverList: model) }
            link("Filament catalog", "books.vertical") { FilamentCatalogView(server: current, serverList: model) }
            link("Spoolman", "spool") { SpoolmanView(server: current, serverList: model) }
            link("Library", "folder") { LibraryListView(server: current, serverList: model) }
            link("Projects", "square.stack.3d.up") { ProjectListView(server: current, serverList: model) }
            link("Smart plugs", "powerplug") { SmartPlugsView(server: current, serverList: model) }
            link("Maintenance", "wrench.and.screwdriver") { MaintenanceView(server: current, serverList: model) }
            link("Firmware", "cpu") { FirmwareView(server: current, serverList: model) }
        }
    }

    /// Section « administration » : réglages, état serveur, sauvegardes, intégrations, compte.
    private var administrationSection: some View {
        Section {
            link("Settings", "gearshape") { SettingsView(server: current, serverList: model) }
            link("Server status", "server.rack") { SystemStatusView(server: current, serverList: model) }
            link("Backups", "externaldrive") { BackupsView(server: current, serverList: model) }
            link("Remote backup", "arrow.up.forward.app") { GitHubBackupView(server: current, serverList: model) }
            link("Discovery", "antenna.radiowaves.left.and.right") { DiscoveryView(server: current, serverList: model) }
            link("Virtual printers", "printer.dotmatrix") { VirtualPrintersView(server: current, serverList: model) }
            link("Support", "stethoscope") { SupportView(server: current, serverList: model) }
            link("API keys", "key") { APIKeysView(server: current, serverList: model) }
            link("External links", "link") { ExternalLinksView(server: current, serverList: model) }
            if current.authMethod == .userPassword {
                link("Account", "person.crop.circle") { AccountView(server: current, serverList: model) }
            }
        }
    }

    /// Fabrique un `NavigationLink` étiqueté homogène (libellé localisé + symbole SF).
    private func link(
        _ title: LocalizedStringKey,
        _ systemImage: String,
        @ViewBuilder destination: () -> some View
    ) -> some View {
        NavigationLink {
            destination()
        } label: {
            Label(title, systemImage: systemImage)
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
