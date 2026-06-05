// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Onglet de premier niveau d'un serveur sélectionné.
enum HomeTab: Hashable {
    case home
    case printers
    case queue
    case library
    case more
}

/// Coquille de navigation par **onglets** appliquée au serveur sélectionné : Accueil · Imprimantes
/// · File · Bibliothèque · Plus. Chaque onglet porte sa propre pile de navigation. La liste des
/// serveurs (multi-serveurs) reste accessible : retour via le bouton dédié de l'en-tête / depuis
/// « Plus → Serveur ». Reflète l'architecture validée sur maquettes (`01-accueil-A`, `03-plus`).
struct ServerHomeView: View {
    let model: ServerListModel
    let server: ServerConfiguration

    /// Retour à la liste des serveurs (multi-serveurs).
    let onBackToServers: () -> Void
    /// Bascule directe vers un autre serveur configuré.
    let onSelectServer: (ServerConfiguration) -> Void

    @State private var selection: HomeTab = .home

    var body: some View {
        TabView(selection: $selection) {
            Tab(value: HomeTab.home) {
                NavigationStack {
                    HomeDashboardView(
                        model: model,
                        server: server,
                        onBackToServers: onBackToServers,
                        onSelectTab: { selection = $0 }
                    )
                }
            } label: {
                Label("Home", systemImage: "house")
            }

            Tab(value: HomeTab.printers) {
                NavigationStack {
                    PrinterListView(server: server, serverList: model)
                }
            } label: {
                Label("Printers", systemImage: "printer")
            }

            Tab(value: HomeTab.queue) {
                NavigationStack {
                    QueueListView(server: server, serverList: model)
                }
            } label: {
                Label("Queue", systemImage: "list.bullet")
            }

            Tab(value: HomeTab.library) {
                NavigationStack {
                    LibraryListView(server: server, serverList: model)
                }
            } label: {
                Label("Library", systemImage: "book")
            }

            Tab(value: HomeTab.more) {
                NavigationStack {
                    MoreView(model: model, server: server, onSelectServer: onSelectServer)
                }
            } label: {
                Label("More", systemImage: "ellipsis")
            }
        }
        .tint(DSColor.accent)
    }
}
