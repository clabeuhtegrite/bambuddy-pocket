// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest

/// Exploration **lecture seule** de tous les écrans contre une instance Bambuddy live, pour la
/// campagne de débogage. Chaque écran est ouvert depuis le détail serveur, capturé, puis on
/// remonte au détail serveur avant le suivant (navigation déterministe). N'actionne **aucun**
/// bouton de contrôle/mutation : uniquement navigation, défilement et captures.
///
/// Skippé hors `UITEST_LIVE=1` (sélection manuelle via le scheme captures).
final class ProdExplorationUITests: XCTestCase {
    private var app: XCUIApplication!

    private let outputDirectory: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("docs/screenshots/explore", isDirectory: true)

    private static let forwardedSeedKeys = [
        "UITEST_SERVER_URL", "UITEST_AUTH_METHOD", "UITEST_API_KEY", "UITEST_BEARER_TOKEN",
        "UITEST_USE_CLOUDFLARE", "UITEST_CF_ID", "UITEST_CF_SECRET"
    ]

    /// Libellés français (l'app tourne en locale fr).
    private enum L {
        static let edit = "Modifier"
        static let testConnection = "Tester la connexion"
        static let links = [
            "Imprimantes", "File d’attente", "Historique d’impression", "Journal d’impression",
            "Activité", "Filaments", "Catalogue de filaments", "Spoolman", "Bibliothèque",
            "Projets", "Prises connectées", "Maintenance", "Micrologiciel", "Réglages",
            "État du serveur", "Clés d’API"
        ]
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["UITEST_LIVE"] == "1",
            "Exploration ignorée hors environnement live (UITEST_LIVE=1)."
        )
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchArguments += [
            "-uitest-seed", "-uitest-appearance", "dark",
            "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR"
        ]
        let environment = ProcessInfo.processInfo.environment
        for key in Self.forwardedSeedKeys where environment[key] != nil {
            app.launchEnvironment[key] = environment[key]
        }
        app.launch()
    }

    func testExploreEveryScreen() {
        let timeout: TimeInterval = 20

        // Détail serveur.
        let serverCell = app.cells.firstMatch
        XCTAssertTrue(serverCell.waitForExistence(timeout: timeout), "server cell")
        serverCell.tap()
        XCTAssertTrue(app.buttons[L.edit].waitForExistence(timeout: timeout), "server detail")
        capture("00-server-detail")

        var index = 1
        for label in L.links {
            backToServerDetail()
            guard openLink(label, timeout: timeout) else { continue }
            sleep(2)
            capture(String(format: "%02d-%@", index, slug(label)))

            // Ouvre le premier détail de liste si présent (lecture seule).
            if let cell = firstListCell(timeout: 4) {
                cell.tap()
                sleep(2)
                capture(String(format: "%02d-%@-detail", index, slug(label)))
            }
            index += 1
        }
    }

    /// Vérifie le **repli REST** du temps réel : sur une instance où le WebSocket est bloqué (ex.
    /// proxy Cloudflare refusant l'upgrade), le détail imprimante doit malgré tout afficher des
    /// données vivantes (statut ≠ « Inconnu ») grâce à `GET /printers/{id}/status`.
    func testPrinterDetailShowsLiveStatus() {
        let timeout: TimeInterval = 20
        let serverCell = app.cells.firstMatch
        XCTAssertTrue(serverCell.waitForExistence(timeout: timeout), "server cell")
        serverCell.tap()
        XCTAssertTrue(app.buttons[L.edit].waitForExistence(timeout: timeout), "server detail")

        XCTAssertTrue(openLink("Imprimantes", timeout: timeout), "printers link")
        sleep(3) // Laisse la liste REST se charger.
        capture("printer-list-live")
        let printerCell = app.cells.firstMatch
        XCTAssertTrue(printerCell.waitForExistence(timeout: timeout), "printer cell")
        printerCell.tap()
        sleep(5) // Laisse le repli REST amorcer le statut détaillé.
        capture("printer-detail-live")

        // « Inconnu » est l'état affiché quand aucune donnée de statut n'est disponible.
        let unknown = app.staticTexts["Inconnu"]
        XCTAssertFalse(unknown.exists, "Le statut ne doit plus être « Inconnu » (repli REST actif).")
    }

    /// Valide la **matrice d'auth** sur les écrans d'administration (Clés d'API + Sauvegarde locale).
    /// Le comportement attendu dépend de `UITEST_AUTH_METHOD` :
    /// - `apikey` : le serveur renvoie 403 → message « admin requis » (pas d'état vide trompeur,
    ///   pas de bouton « Créer une clé d'API » / « Sauvegarder maintenant »).
    /// - `userpassword` : session JWT → les écrans chargent les vraies données (200).
    func testAdminScreensAuthMatrix() throws {
        let timeout: TimeInterval = 25
        let method = ProcessInfo.processInfo.environment["UITEST_AUTH_METHOD"]?.lowercased() ?? ""
        let serverCell = app.cells.firstMatch
        XCTAssertTrue(serverCell.waitForExistence(timeout: timeout), "server cell")
        serverCell.tap()
        XCTAssertTrue(app.buttons[L.edit].waitForExistence(timeout: timeout), "server detail")

        // — Écran Clés d'API —
        // NB : sous iOS 26, XCUITest ne défile pas de façon fiable une `List` SwiftUI, donc atteindre
        // les liens du **bas** de la liste de détail peut échouer côté harnais (et non côté app). On
        // ignore alors le test plutôt que de signaler une fausse régression — la matrice d'auth reste
        // couverte au niveau réseau (RESTClient 403→forbidden) et message (ErrorMessageTests).
        try XCTSkipUnless(
            tapAdminLink("Clés d’API", timeout: timeout),
            "lien Clés d'API inatteignable (défilement XCUITest iOS 26)"
        )
        sleep(3)
        capture("auth-\(method)-api-keys")
        assertAdminScreen(method: method, createLabel: "Créer une clé d’API")

        // — Écran Sauvegarde locale (lien de premier niveau dans la section administration) —
        backToServerDetail()
        if tapAdminLink("Sauvegardes", timeout: timeout) {
            sleep(3)
            capture("auth-\(method)-backups")
            assertAdminScreen(method: method, createLabel: "Sauvegarder maintenant")
        }
    }

    /// Tente d'ouvrir le lien d'administration `label` (Clés d'API, Sauvegardes), en bas de la liste
    /// de détail. Renvoie `false` si le lien reste inatteignable (le défilement synthétique d'une
    /// `List` SwiftUI est peu fiable sous iOS 26) — l'appelant ignore alors proprement le test.
    private func tapAdminLink(_ label: String, timeout: TimeInterval) -> Bool {
        let link = app.staticTexts[label]
        guard link.waitForExistence(timeout: timeout) else { return false }
        // Tente d'amener le lien à l'écran. NB : sous iOS 26, le défilement synthétique d'une `List`
        // SwiftUI via XCUITest est peu fiable ; si le lien (en bas de la liste) reste inatteignable,
        // l'appelant ignore proprement le test plutôt que de signaler une fausse régression.
        var scrolls = 0
        while !link.isHittable, scrolls < 10 {
            app.swipeUp()
            scrolls += 1
        }
        guard link.isHittable else { return false }
        link.tap()
        return true
    }

    /// Selon la méthode d'auth, vérifie soit le message « admin requis » + absence d'action (clé
    /// d'API → 403), soit l'absence de ce message (session → 200, vraies données chargées).
    private func assertAdminScreen(method: String, createLabel: String) {
        let adminRequired = app.staticTexts["Connexion administrateur requise"]
        let oldMisleading = app.staticTexts["Non autorisé — vérifie tes identifiants."]
        XCTAssertFalse(oldMisleading.exists, "Le message ne doit jamais suggérer des identifiants erronés.")
        if method == "apikey" {
            XCTAssertTrue(adminRequired.waitForExistence(timeout: 6), "403 → message « admin requis »")
            XCTAssertFalse(app.buttons[createLabel].exists, "Aucun bouton d'action au-dessus d'un 403.")
        } else if method == "userpassword" {
            XCTAssertFalse(adminRequired.exists, "Session JWT → l'écran admin doit charger (pas de 403).")
        }
    }

    // MARK: Helpers

    private func openLink(_ label: String, timeout: TimeInterval) -> Bool {
        let button = app.buttons[label]
        let text = app.staticTexts[label]
        let element = button.exists ? button : text
        guard element.waitForExistence(timeout: timeout) else { return false }
        // Défile (plusieurs fois si besoin) pour atteindre les liens en bas de liste.
        var scrolls = 0
        while !element.isHittable, scrolls < 8 {
            app.swipeUp()
            scrolls += 1
        }
        guard element.isHittable else { return false }
        element.tap()
        return true
    }

    private func firstListCell(timeout: TimeInterval) -> XCUIElement? {
        let cell = app.cells.element(boundBy: 0)
        guard cell.waitForExistence(timeout: timeout), cell.isHittable else { return nil }
        return cell
    }

    private func backToServerDetail() {
        for _ in 0 ..< 8 {
            if app.buttons[L.testConnection].exists || app.buttons[L.edit].exists,
               app.buttons[L.links[0]].exists
            {
                return
            }
            let back = app.navigationBars.buttons.firstMatch
            if back.exists, back.isHittable { back.tap()
                sleep(1)
            } else { break }
        }
    }

    private func slug(_ label: String) -> String {
        label.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "’", with: "")
            .replacingOccurrences(of: " ", with: "-")
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        try? screenshot.pngRepresentation.write(to: outputDirectory.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
