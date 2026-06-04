// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest

/// Capture les écrans principaux de l'app (tournant contre l'instance Docker locale) en PNG sur
/// disque, pour la revue de présentation. L'app est amorcée avec un serveur de démo via l'argument
/// de lancement `-uitest-seed` (cf. `BambuddyPocketApp`), de sorte que les écrans affichent des
/// données réelles. Les fichiers sont écrits dans `docs/screenshots/` à la racine du dépôt.
final class ScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    /// Dossier de sortie : `<repo>/docs/screenshots`, dérivé du chemin source de ce fichier.
    private let outputDirectory: URL = .init(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // BambuddyPocketUITests
        .deletingLastPathComponent() // <repo>
        .appendingPathComponent("docs/screenshots", isDirectory: true)

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )
        app = XCUIApplication()
        // Force English so screenshots and selectors are deterministic regardless of the host
        // simulator locale.
        app.launchArguments += ["-uitest-seed", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
    }

    func testCaptureMainScreens() {
        let timeout: TimeInterval = 15

        // 01 — Liste des serveurs
        capture("01-servers")

        // Détail serveur : tap sur la ligne du serveur de démo.
        let serverCell = app.cells.firstMatch
        XCTAssertTrue(serverCell.waitForExistence(timeout: timeout), "server cell")
        serverCell.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: timeout), "server detail")
        capture("02-server-detail")

        // 03 — Centre de notifications (bouton cloche dans la barre).
        if app.buttons["Notifications"].waitForExistence(timeout: 5) {
            app.buttons["Notifications"].tap()
            _ = app.navigationBars["Notifications"].waitForExistence(timeout: 5)
            capture("03-notifications")
            tapIfExists(app.buttons["Done"])
        }

        // Imprimantes
        navigate(to: "Printers", screenshot: "04-printers", timeout: timeout)
        // Détail imprimante (première ligne).
        if tapFirstCell(timeout: timeout) {
            sleep(2)
            capture("05-printer-detail")
            // Caméra, accessible depuis le détail.
            tapFirst(["Camera", "Caméra"], screenshot: "06-camera", settle: 3)
            goBackIfPossible()
            goBackIfPossible()
        }

        // File d'attente
        navigate(to: "Print queue", screenshot: "07-queue", timeout: timeout)
        // Archives (liste + détail).
        navigate(to: "Print history", screenshot: "08-archives", timeout: timeout)
        if tapFirstCell(timeout: timeout) {
            sleep(2)
            capture("09-archive-detail")
            goBackIfPossible()
        }

        // Inventaire
        navigate(to: "Filaments", screenshot: "10-inventory", timeout: timeout)
        // Bibliothèque
        navigate(to: "Library", screenshot: "11-library", timeout: timeout)
        // Projets
        navigate(to: "Projects", screenshot: "12-projects", timeout: timeout)
        // Activité
        navigate(to: "Activity", screenshot: "13-activity", timeout: timeout)

        // Ajout de serveur (depuis la liste des serveurs).
        backToRoot()
        if app.buttons["Add server"].waitForExistence(timeout: 5) {
            app.buttons["Add server"].tap()
            sleep(1)
            capture("14-add-server")
            tapFirst(["Cancel", "Annuler"], screenshot: nil)
        }

        // À propos.
        if app.buttons["About"].waitForExistence(timeout: 5) {
            app.buttons["About"].tap()
            sleep(1)
            capture("15-about")
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

    /// Remonte jusqu'au détail serveur, identifié par le bouton « Test connection » (unique à cet
    /// écran — les libellés de liens comme « Filaments » sont aussi des titres d'autres écrans).
    private func backToServerDetail() {
        for _ in 0 ..< 6 {
            if app.buttons["Test connection"].exists { return }
            goBackIfPossible()
        }
        _ = app.buttons["Test connection"].waitForExistence(timeout: 5)
    }

    private func backToRoot() {
        for _ in 0 ..< 6 where app.navigationBars.buttons.firstMatch.exists {
            let back = app.navigationBars.buttons.firstMatch
            guard back.isHittable, back.label != "Add server" else { break }
            // S'arrêter une fois revenu à la liste des serveurs (bouton « Add server » présent).
            if app.buttons["Add server"].exists { break }
            back.tap()
            sleep(1)
        }
    }
}
