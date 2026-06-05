// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest

/// Capture les écrans de la **refonte UI/UX** (navigation par onglets + accueil A) en PNG sur
/// disque, pour comparaison aux maquettes (`docs/mockups/`). L'app est amorcée avec un serveur de
/// démo via `-uitest-seed` (cf. `BamPocketApp`) pointant sur l'instance Docker locale, de sorte que
/// les écrans affichent des données réelles. Captures en **français**, en thème **sombre** (DA
/// Bambuddy) et **clair**. Sortie : `docs/screenshots/refonte/`.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    /// Dossier de sortie : `<repo>/docs/screenshots/refonte`, dérivé du chemin source de ce fichier.
    private let outputDirectory: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // BambuddyPocketUITests
        .deletingLastPathComponent() // <repo>
        .appendingPathComponent("docs/screenshots/refonte", isDirectory: true)

    /// Libellés français utilisés comme sélecteurs (l'app tourne en locale fr).
    private enum L {
        static let home = "Accueil"
        static let printers = "Imprimantes"
        static let more = "Plus"
        static let queue = "File"
        static let archives = "Archives"
        static let homeLayout = "Disposition d’accueil"
        static let grid = "Grille"
        static let bambuCloud = "Bambu Cloud"
        static let makerWorld = "MakerWorld"
    }

    override func setUpWithError() throws {
        // Ces captures s'appuient sur un backend Bambuddy en marche (Docker local) pour afficher des
        // données réelles ; non déterministes en CI. On les exécute uniquement quand `UITEST_LIVE=1`.
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["UITEST_LIVE"] == "1",
            "Captures ignorées hors environnement live (UITEST_LIVE=1)."
        )
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    /// Variables d'environnement de configuration du seed transmises à l'app sous test. Lues
    /// uniquement depuis l'environnement du processus de test (jamais codées en dur).
    private static let forwardedSeedKeys = [
        "UITEST_SERVER_URL",
        "UITEST_AUTH_METHOD",
        "UITEST_API_KEY",
        "UITEST_USE_CLOUDFLARE",
        "UITEST_CF_ID",
        "UITEST_CF_SECRET"
    ]

    private func launch(appearance: String) {
        app = XCUIApplication()
        app.launchArguments += [
            "-uitest-seed",
            "-uitest-appearance", appearance,
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR"
        ]
        let environment = ProcessInfo.processInfo.environment
        for key in Self.forwardedSeedKeys where environment[key] != nil {
            app.launchEnvironment[key] = environment[key]
        }
        app.launch()
    }

    func testCaptureRedesignScreens() {
        let timeout: TimeInterval = 15
        launch(appearance: "dark")

        // Sélectionne le serveur de démo → coquille à onglets (onglet Accueil).
        let serverCell = app.cells.firstMatch
        XCTAssertTrue(serverCell.waitForExistence(timeout: timeout), "server cell")
        serverCell.tap()

        // 01 — Accueil A (sombre) + barre d'onglets.
        XCTAssertTrue(app.tabBars.buttons[L.home].waitForExistence(timeout: timeout), "tab bar")
        sleep(3) // laisse le temps réel peupler la carte hero / les cartes imprimantes
        capture("01-accueil-sombre")

        // 02 — Onglet Imprimantes + détail B (première imprimante).
        app.tabBars.buttons[L.printers].tap()
        sleep(2)
        capture("02-imprimantes")
        if tapFirstCell(timeout: timeout) {
            sleep(3)
            capture("03-detail-imprimante-B")
            goBackIfPossible()
        }

        // 03b — Onglet Archives (remplace l'ancien onglet Bibliothèque).
        if app.tabBars.buttons[L.archives].waitForExistence(timeout: timeout) {
            app.tabBars.buttons[L.archives].tap()
            sleep(2)
            capture("03b-archives")
        }

        // 04 — Onglet Plus (groupé).
        app.tabBars.buttons[L.more].tap()
        sleep(1)
        capture("04-plus")

        // 06 — MakerWorld (depuis Plus → Contenu).
        if openFromMore(L.makerWorld, timeout: timeout) {
            sleep(2)
            capture("06-makerworld")
            goBackIfPossible()
        }

        // 07 — Bambu Cloud (depuis Plus → Serveur).
        app.tabBars.buttons[L.more].tap()
        sleep(1)
        if openFromMore(L.bambuCloud, timeout: timeout) {
            sleep(2)
            capture("07-bambu-cloud")
            goBackIfPossible()
        }

        // 08 — Accueil C (grille) : bascule via le menu de disposition.
        app.tabBars.buttons[L.home].tap()
        sleep(2)
        if switchHomeLayout(to: L.grid, timeout: timeout) {
            sleep(3)
            capture("08-accueil-grille")
        }

        // 05 — Accueil A (clair).
        app.terminate()
        launch(appearance: "light")
        let cellLight = app.cells.firstMatch
        if cellLight.waitForExistence(timeout: timeout) {
            cellLight.tap()
            _ = app.tabBars.buttons[L.home].waitForExistence(timeout: timeout)
            sleep(3)
            capture("05-accueil-clair")
        }
    }

    // MARK: Helpers

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let url = outputDirectory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("write \(name): \(error)")
        }
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Tape la première ligne de liste, avec un repli en coordonnées si elle n'est pas « hittable ».
    @discardableResult
    private func tapFirstCell(timeout: TimeInterval) -> Bool {
        let cell = app.cells.element(boundBy: 0)
        guard cell.waitForExistence(timeout: timeout) else { return false }
        sleep(1)
        if cell.isHittable {
            cell.tap()
        } else {
            cell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        return true
    }

    private func goBackIfPossible() {
        let back = app.navigationBars.buttons.firstMatch
        if back.exists, back.isHittable {
            back.tap()
            sleep(1)
        }
    }

    /// Ouvre un lien de l'onglet Plus (avec défilement si besoin). Renvoie `false` s'il reste
    /// introuvable.
    @discardableResult
    private func openFromMore(_ label: String, timeout: TimeInterval) -> Bool {
        let link = app.buttons[label]
        var attempts = 0
        while !link.exists, attempts < 5 {
            app.swipeUp()
            attempts += 1
        }
        guard link.waitForExistence(timeout: timeout) else { return false }
        while !link.isHittable, attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        if link.isHittable {
            link.tap()
        } else {
            link.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        return true
    }

    /// Bascule la disposition d'accueil via le menu de la barre d'outils (libellé d'accessibilité).
    @discardableResult
    private func switchHomeLayout(to option: String, timeout: TimeInterval) -> Bool {
        let menu = app.buttons[L.homeLayout]
        guard menu.waitForExistence(timeout: timeout), menu.isHittable else { return false }
        menu.tap()
        let choice = app.buttons[option]
        guard choice.waitForExistence(timeout: timeout) else { return false }
        choice.tap()
        return true
    }
}
