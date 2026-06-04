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
        "UITEST_SERVER_URL", "UITEST_AUTH_METHOD", "UITEST_API_KEY",
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

    // MARK: Helpers

    private func openLink(_ label: String, timeout: TimeInterval) -> Bool {
        let button = app.buttons[label]
        let text = app.staticTexts[label]
        let element = button.exists ? button : text
        guard element.waitForExistence(timeout: timeout) else { return false }
        // Défile pour atteindre les liens du bas si besoin.
        if !element.isHittable { app.swipeUp() }
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
