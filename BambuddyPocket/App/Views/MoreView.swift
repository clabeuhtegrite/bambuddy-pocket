// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Onglet « Plus » : regroupe en sections les écrans qui ne sont pas des onglets de premier
/// niveau (production, matériaux, contenu, matériel, serveur, à propos). Remplace l'ancien mur de
/// menus du détail serveur. Reflète la hiérarchie validée sur maquette (`03-plus-hierarchie`).
struct MoreView: View {
    let model: ServerListModel
    let server: ServerConfiguration
    /// Bascule vers un autre serveur configuré (multi-serveurs).
    var onSelectServer: ((ServerConfiguration) -> Void)?

    @State private var showingAbout = false

    /// Configuration à jour (relue après une édition), repli sur la valeur initiale.
    private var current: ServerConfiguration {
        model.servers.first { $0.id == server.id } ?? server
    }

    var body: some View {
        List {
            productionSection
            materialsSection
            contentSection
            hardwareSection
            serverSection
            aboutSection
        }
        .dsListBackground()
        .navigationTitle("More")
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }

    /// Production : file, historique, activité.
    private var productionSection: some View {
        Section("Production") {
            link("Print queue", "list.number") { QueueListView(server: current, serverList: model) }
            link("Print history", "clock.arrow.circlepath") { ArchiveListView(server: current, serverList: model) }
            link("Activity", "waveform.path.ecg") { ActivityListView(server: current, serverList: model) }
            link("Print log", "doc.text.below.ecg") { PrintLogView(server: current, serverList: model) }
        }
    }

    /// Matériaux : filaments/inventaire, catalogue, Spoolman.
    private var materialsSection: some View {
        Section("Materials") {
            link("Filaments", "circle.dashed") { InventoryListView(server: current, serverList: model) }
            link("Filament catalog", "books.vertical") { FilamentCatalogView(server: current, serverList: model) }
            // `spool` n'existe pas comme symbole SF sur le SDK cible → `cylinder` (présent).
            link("Spoolman", "cylinder") { SpoolmanView(server: current, serverList: model) }
        }
    }

    /// Contenu : bibliothèque, projets, MakerWorld.
    private var contentSection: some View {
        Section("Content") {
            link("Library", "folder") { LibraryListView(server: current, serverList: model) }
            link("Projects", "square.stack.3d.up") { ProjectListView(server: current, serverList: model) }
            link("MakerWorld", "globe") { MakerWorldView(server: current, serverList: model) }
        }
    }

    /// Matériel : prises, maintenance, micrologiciel, imprimantes virtuelles, découverte.
    private var hardwareSection: some View {
        Section("Hardware") {
            link("Smart plugs", "powerplug") { SmartPlugsView(server: current, serverList: model) }
            link("Maintenance", "wrench.and.screwdriver") { MaintenanceView(server: current, serverList: model) }
            link("Firmware", "cpu") { FirmwareView(server: current, serverList: model) }
            link("Virtual printers", "printer.dotmatrix") { VirtualPrintersView(server: current, serverList: model) }
            link("Discovery", "antenna.radiowaves.left.and.right") { DiscoveryView(server: current, serverList: model) }
        }
    }

    /// Serveur : réglages, état, clés d'API, sauvegardes, liens externes, compte, connexion.
    private var serverSection: some View {
        Section("Server") {
            link("Settings", "gearshape") { SettingsView(server: current, serverList: model) }
            link("Server status", "server.rack") { SystemStatusView(server: current, serverList: model) }
            link("API keys", "key") { APIKeysView(server: current, serverList: model) }
            link("Backups", "externaldrive") { BackupsView(server: current, serverList: model) }
            link("Remote backup", "arrow.up.forward.app") { GitHubBackupView(server: current, serverList: model) }
            link("Bambu Cloud", "cloud") { CloudAccountView(server: current, serverList: model) }
            link("External links", "link") { ExternalLinksView(server: current, serverList: model) }
            link("Support", "stethoscope") { SupportView(server: current, serverList: model) }
            if current.authMethod == .userPassword {
                link("Account", "person.crop.circle") { AccountView(server: current, serverList: model) }
            }
            // Connexion / serveurs : test, édition, suppression, bascule de serveur.
            link("Server & connection", "network") {
                ServerInfoView(model: model, server: current, onSelectServer: onSelectServer)
            }
        }
    }

    private var aboutSection: some View {
        Section {
            Button {
                showingAbout = true
            } label: {
                Label("About", systemImage: "info.circle")
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
}

#Preview {
    NavigationStack {
        MoreView(
            model: ServerListModel(environment: .inMemory()),
            server: ServerConfiguration(
                label: "Atelier",
                baseURL: URL(string: "http://192.168.1.50:8000") ?? URL(filePath: "/")
            )
        )
    }
}
