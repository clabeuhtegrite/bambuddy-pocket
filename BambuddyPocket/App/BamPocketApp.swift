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
        UITestSeed.seedDemoIfRequested()
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
/// configuré depuis des variables d'environnement (URL, méthode d'auth, Cloudflare Access) afin
/// que les écrans de captures affichent des données réelles. Les secrets éventuels (clé d'API,
/// JWT de session pour `.userPassword`, service token Cloudflare) sont lus dans l'environnement et
/// écrits dans le Keychain — jamais codés en dur. Aucun effet en production (ces arguments ne sont
/// jamais passés par un build normal).
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

    /// Amorçage du **mode démo** (`-uitest-demo`, captures marketing) : enregistre un serveur
    /// pointant sur l'hôte synthétique `demo.local`, dont toutes les requêtes sont servies par
    /// `DemoURLProtocol` (fixtures locales). Aucun secret, aucun backend, aucune imprimante réelle.
    static func seedDemoIfRequested() {
        // Le mode démo (fixtures locales, captures marketing) n'existe qu'en Debug ; en Release,
        // `DemoMode` est compilé hors binaire et cette amorce est un no-op.
        #if DEBUG
            guard DemoMode.isEnabled, let url = URL(string: "http://\(DemoMode.host)") else { return }
            let server = ServerConfiguration(
                label: "Atelier",
                baseURL: url,
                authMethod: .none,
                usesCloudflareAccess: false,
                allowsInsecureLocalHTTP: true
            )
            try? UserDefaultsServerStore().save([server])
        #endif
    }

    static func seedIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-uitest-seed") else { return }
        let environment = ProcessInfo.processInfo.environment
        let urlString = environment["UITEST_SERVER_URL"] ?? "http://localhost:8000"
        guard let url = URL(string: urlString) else { return }

        let authMethod: AuthMethod = switch environment["UITEST_AUTH_METHOD"]?.lowercased() {
        case "apikey": .apiKey
        case "userpassword": .userPassword
        default: .none
        }
        let usesCloudflare = boolEnv(environment["UITEST_USE_CLOUDFLARE"])
        let isInsecureLocal = url.scheme?.lowercased() == "http"

        let server = ServerConfiguration(
            label: "Atelier (démo)",
            baseURL: url,
            authMethod: authMethod,
            usesCloudflareAccess: usesCloudflare,
            allowsInsecureLocalHTTP: isInsecureLocal
        )

        // Les secrets ne sont jamais en dur : ils proviennent exclusivement de variables
        // d'environnement transitoires passées au lancement du simulateur. On les écrit dans
        // le Keychain via le même `SecretStore` que l'app utilise en production.
        let secrets = ServerSecrets(
            apiKey: authMethod == .apiKey ? environment["UITEST_API_KEY"] : nil,
            // JWT de session (méthode `.userPassword`) fourni au runtime via l'environnement —
            // jamais codé en dur. Le harnais l'obtient par un login `POST /auth/login` avant de
            // lancer le simulateur, puis le transmet en `SIMCTL_CHILD_UITEST_BEARER_TOKEN`.
            bearerToken: authMethod == .userPassword ? environment["UITEST_BEARER_TOKEN"] : nil,
            cloudflareClientID: usesCloudflare ? environment["UITEST_CF_ID"] : nil,
            cloudflareClientSecret: usesCloudflare ? environment["UITEST_CF_SECRET"] : nil
        )

        try? UserDefaultsServerStore().save([server])
        if !secrets.isEmpty {
            try? KeychainSecretStore().setSecrets(secrets, for: server.id)
        }
    }

    /// Interprète une variable d'environnement booléenne (`1`/`true`/`yes`, insensible à la casse).
    private static func boolEnv(_ value: String?) -> Bool {
        switch value?.lowercased() {
        case "1", "true", "yes": true
        default: false
        }
    }
}
