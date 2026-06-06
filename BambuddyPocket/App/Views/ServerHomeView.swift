// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Onglet de premier niveau d'un serveur sélectionné.
enum HomeTab: Hashable {
    case home
    case printers
    case queue
    case archives
    case more
}

/// Disposition de l'écran d'accueil, choisie par l'utilisateur (persistée via `@AppStorage`).
/// Reflète les maquettes : A = tableau de bord, B = focus imprimante, C = grille flotte.
enum HomeVariant: String, CaseIterable, Identifiable {
    /// A — tableau de bord : carte hero + cartes compactes + activité (maquette `01-accueil-A`).
    case dashboard
    /// B — focus imprimante : grande carte hero seule, le reste replié (maquette `02-accueil-B`).
    case focus
    /// C — grille flotte : bandeau de compteurs + grille d'imprimantes (maquette `06-accueil-C`).
    case grid

    var id: String {
        rawValue
    }

    /// Libellé localisé court pour le sélecteur de vue.
    var label: LocalizedStringKey {
        switch self {
        case .dashboard: "Dashboard"
        case .focus: "Focus"
        case .grid: "Grid"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "square.grid.2x2"
        case .focus: "rectangle.portrait"
        case .grid: "square.grid.3x3"
        }
    }
}

/// Coquille de navigation par **onglets** appliquée au serveur sélectionné : Accueil · Imprimantes
/// · File · Archives · Plus. Chaque onglet porte sa propre pile de navigation. La liste des
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
        tabView
            // Disposition **adaptative** : barre d'onglets sur iPhone (compact), **sidebar/colonnes**
            // sur iPad (régulier). `.sidebarAdaptable` est l'approche Apple pour une coquille à
            // onglets qui devient un split view sur grand écran — sans rien changer à l'iPhone.
            .tabViewStyle(.sidebarAdaptable)
            .tint(DSColor.accent)
    }

    private var tabView: some View {
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

            Tab(value: HomeTab.archives) {
                NavigationStack {
                    ArchiveListView(server: server, serverList: model)
                }
            } label: {
                Label("Archives", systemImage: "archivebox")
            }

            Tab(value: HomeTab.more) {
                NavigationStack {
                    MoreView(model: model, server: server, onSelectServer: onSelectServer)
                }
            } label: {
                Label("More", systemImage: "ellipsis")
            }
        }
    }
}
