// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import BambuddyPocketNetworking
import SwiftUI

@main
struct BambuddyPocketApp: App {
    @State private var model: ServerListModel

    init() {
        UITestSeed.seedIfRequested()
        _model = State(initialValue: ServerListModel(environment: .live()))
    }

    var body: some Scene {
        WindowGroup {
            ServerListView(model: model)
                .tint(DSColor.accent)
        }
    }
}

/// Amorçage **uniquement pour les captures d'écran XCUITest** : si l'argument de lancement
/// `-uitest-seed` est présent, enregistre un serveur de démonstration pointant sur l'instance
/// Docker locale (auth désactivée) afin que les écrans affichent des données réelles. Aucun effet
/// en production (l'argument n'est jamais passé par un build normal).
private enum UITestSeed {
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
