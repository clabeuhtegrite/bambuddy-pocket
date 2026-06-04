// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import BambuddyPocketNetworking
import SwiftUI

@main
struct BamPocketApp: App {
    @State private var model: ServerListModel

    init() {
        UITestSeed.resetIfRequested()
        UITestSeed.seedIfRequested()
        _model = State(initialValue: ServerListModel(environment: .live()))
    }

    var body: some Scene {
        WindowGroup {
            ServerListView(model: model)
                .tint(DSColor.accent)
                .preferredColorScheme(UITestSeed.forcedColorScheme)
        }
    }
}

/// Amorçage **uniquement pour les tests XCUITest**. `-uitest-fresh` repart d'une liste vide
/// (parcours critiques déterministes). `-uitest-seed` enregistre un serveur de démonstration
/// pointant sur l'instance Docker locale (auth désactivée) afin que les écrans de captures
/// affichent des données réelles. Aucun effet en production (ces arguments ne sont jamais passés
/// par un build normal).
private enum UITestSeed {
    /// Schéma de couleurs forcé pour les captures XCUITest (`-uitest-appearance dark|light`).
    /// `nil` en build normal → l'app suit le réglage système.
    static var forcedColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-uitest-appearance"),
              index + 1 < arguments.count
        else {
            return nil
        }
        switch arguments[index + 1].lowercased() {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    /// Repart d'une liste de serveurs **vide** pour les tests XCUITest déterministes
    /// (`-uitest-fresh`). Sans effet en build normal.
    static func resetIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-uitest-fresh") else { return }
        try? UserDefaultsServerStore().save([])
    }

    static func seedIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-uitest-seed") else { return }
        let urlString = ProcessInfo.processInfo.environment["UITEST_SERVER_URL"]
            ?? "http://localhost:8000"
        guard let url = URL(string: urlString) else { return }
        let server = ServerConfiguration(
            label: "Atelier (démo)",
            baseURL: url,
            authMethod: .none,
            allowsInsecureLocalHTTP: true
        )
        try? UserDefaultsServerStore().save([server])
    }
}
