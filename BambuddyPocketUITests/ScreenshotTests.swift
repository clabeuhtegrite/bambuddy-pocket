// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest

/// Capture les écrans principaux de l'app (tournant contre l'instance Docker locale) en PNG sur
/// disque, pour la revue de présentation. L'app est amorcée avec un serveur de démo via l'argument
/// de lancement `-uitest-seed` (cf. `BamPocketApp`), de sorte que les écrans affichent des
/// données réelles. Les captures sont produites en **français** et, par défaut, en **thème sombre**
/// (le plus représentatif de la DA Bambuddy) ; deux écrans clés sont aussi capturés en thème clair
/// pour illustrer l'adaptation. Les fichiers sont écrits dans `docs/screenshots/`.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    /// Dossier de sortie : `<repo>/docs/screenshots`, dérivé du chemin source de ce fichier.
    private let outputDirectory: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // BambuddyPocketUITests
        .deletingLastPathComponent() // <repo>
        .appendingPathComponent("docs/screenshots", isDirectory: true)

    /// Libellés français utilisés comme sélecteurs (l'app tourne en locale fr).
    private enum L {
        static let edit = "Modifier"
        static let done = "Terminé"
        static let about = "À propos"
        static let notifications = "Notifications"
        static let addServer = "Ajouter un serveur"
        static let testConnection = "Tester la connexion"
        static let cancel = "Annuler"
        static let printers = "Imprimantes"
        static let queue = "File d’attente"
        static let history = "Historique d’impression"
        static let filaments = "Filaments"
        static let library = "Bibliothèque"
        static let projects = "Projets"
        static let activity = "Activité"
        static let camera = "Caméra"
    }

    override func setUpWithError() throws {
        // Ces captures s'appuient sur un backend Bambuddy en marche (Docker local) pour afficher
        // des données réelles ; elles ne sont donc PAS déterministes en CI. On les exécute
        // uniquement quand `UITEST_LIVE=1` est fourni (lancement manuel via le scheme captures).
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["UITEST_LIVE"] == "1",
            "Captures ignorées hors environnement live (UITEST_LIVE=1)."
        )
        continueAfterFailure = true
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Lance l'app en français, avec le thème demandé.
    private func launch(appearance: String) {
        app = XCUIApplication()
        app.launchArguments += [
            "-uitest-seed",
            "-uitest-appearance", appearance,
            "-AppleLanguages", "(fr)",
            "-AppleLocale", "fr_FR"
        ]
        app.launch()
    }

    func testCaptureMainScreens() {
        let timeout: TimeInterval = 15
        launch(appearance: "dark")

        // 01 — Liste des serveurs
        capture("01-servers")

        // Détail serveur : tap sur la ligne du serveur de démo.
        let serverCell = app.cells.firstMatch
        XCTAssertTrue(serverCell.waitForExistence(timeout: timeout), "server cell")
        serverCell.tap()
        XCTAssertTrue(app.buttons[L.edit].waitForExistence(timeout: timeout), "server detail")
        capture("02-server-detail")

        // 03 — Centre de notifications (bouton cloche dans la barre).
        if app.buttons[L.notifications].waitForExistence(timeout: 5) {
            app.buttons[L.notifications].tap()
            _ = app.navigationBars[L.notifications].waitForExistence(timeout: 5)
            capture("03-notifications")
            tapIfExists(app.buttons[L.done])
        }

        // Imprimantes
        navigate(to: L.printers, screenshot: "04-printers", timeout: timeout)
        // Détail imprimante (première ligne).
        if tapFirstCell(timeout: timeout) {
            sleep(2)
            capture("05-printer-detail")
            // Caméra, accessible depuis le détail.
            tapFirst([L.camera, "Camera"], screenshot: "06-camera", settle: 3)
            goBackIfPossible()
            goBackIfPossible()
        }

        // File d'attente
        navigate(to: L.queue, screenshot: "07-queue", timeout: timeout)
        // Archives (liste + détail).
        navigate(to: L.history, screenshot: "08-archives", timeout: timeout)
        if tapFirstCell(timeout: timeout) {
            sleep(2)
            capture("09-archive-detail")
            goBackIfPossible()
        }

        // Inventaire
        navigate(to: L.filaments, screenshot: "10-inventory", timeout: timeout)
        // Bibliothèque
        navigate(to: L.library, screenshot: "11-library", timeout: timeout)
        // Projets
        navigate(to: L.projects, screenshot: "12-projects", timeout: timeout)
        // Activité
        navigate(to: L.activity, screenshot: "13-activity", timeout: timeout)

        // Ajout de serveur (depuis la liste des serveurs).
        backToRoot()
        if app.buttons[L.addServer].waitForExistence(timeout: 5) {
            app.buttons[L.addServer].tap()
            sleep(1)
            capture("14-add-server")
            tapFirst([L.cancel, "Cancel"], screenshot: nil)
        }

        // À propos.
        if app.buttons[L.about].waitForExistence(timeout: 5) {
            app.buttons[L.about].tap()
            sleep(1)
            capture("15-about")
        }

        // Deux écrans clés en thème clair pour illustrer l'adaptation.
        captureLightVariants(timeout: timeout)
    }

    /// Relance l'app en thème clair et capture les imprimantes (liste + détail).
    private func captureLightVariants(timeout: TimeInterval) {
        app.terminate()
        launch(appearance: "light")

        let serverCell = app.cells.firstMatch
        guard serverCell.waitForExistence(timeout: timeout) else { return }
        serverCell.tap()
        guard app.buttons[L.edit].waitForExistence(timeout: timeout) else { return }

        navigate(to: L.printers, screenshot: "04-printers-light", timeout: timeout)
        if tapFirstCell(timeout: timeout) {
            sleep(2)
            capture("05-printer-detail-light")
        }
    }

    // MARK: Helpers

    /// Ouvre un lien du détail serveur, capture, puis revient.
    private func navigate(to label: String, screenshot name: String, timeout: TimeInterval) {
        backToServerDetail()
        let link = serverDetailLink(label)
        guard link.waitForExistence(timeout: timeout), link.isHittable else {
            XCTFail("missing navigation link: \(label)")
            return
        }
        link.tap()
        sleep(2)
        capture(name)
    }

    /// Lien de navigation du détail serveur, identifié par son libellé (bouton ou texte).
    private func serverDetailLink(_ label: String) -> XCUIElement {
        app.buttons[label].exists ? app.buttons[label] : app.staticTexts[label]
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let url = outputDirectory.appendingPathComponent("\(name).png")
        do {
            try screenshot.pngRepresentation.write(to: url)
        } catch {
            XCTFail("write \(name): \(error)")
        }
        // Aussi attaché au rapport de test pour visibilité.
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tapFirst(_ labels: [String], screenshot name: String?, settle: UInt32 = 1) {
        for label in labels {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 3) {
                button.tap()
                sleep(settle)
                if let name { capture(name) }
                return
            }
        }
    }

    private func tapIfExists(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 3) { element.tap() }
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

    /// Remonte jusqu'au détail serveur, identifié par le bouton « Tester la connexion » (unique à
    /// cet écran — les libellés de liens comme « Filaments » sont aussi des titres d'autres écrans).
    private func backToServerDetail() {
        for _ in 0 ..< 6 {
            if app.buttons[L.testConnection].exists { return }
            goBackIfPossible()
        }
        _ = app.buttons[L.testConnection].waitForExistence(timeout: 5)
    }

    private func backToRoot() {
        for _ in 0 ..< 6 where app.navigationBars.buttons.firstMatch.exists {
            let back = app.navigationBars.buttons.firstMatch
            guard back.isHittable, back.label != L.addServer else { break }
            // S'arrêter une fois revenu à la liste des serveurs (bouton d'ajout présent).
            if app.buttons[L.addServer].exists { break }
            back.tap()
            sleep(1)
        }
    }
}
