// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest

/// Capture les **écrans phares marketing App Store** en mode démo (`-uitest-demo`) : données
/// synthétiques riches servies localement (`DemoURLProtocol`), aucun backend ni imprimante réelle.
/// Cinq écrans : Accueil, détail imprimante (cartes + AMS), Archives, viewer 3D, File d'attente.
///
/// Lancé avec une locale (`SCREENSHOT_LANG`, défaut `fr`) et un thème (`SCREENSHOT_APPEARANCE`,
/// défaut `dark`). Ignoré hors `SCREENSHOT_CAPTURE=1` (déterministe mais réservé au harnais de
/// captures, pas à la CI). Sortie : `docs/appstore/screenshots/<lang>/`.
final class AppStoreScreenshotTests: XCTestCase {
    private var app: XCUIApplication!

    private var language: String {
        ProcessInfo.processInfo.environment["SCREENSHOT_LANG"] ?? "fr"
    }

    private var appearance: String {
        ProcessInfo.processInfo.environment["SCREENSHOT_APPEARANCE"] ?? "dark"
    }

    private var outputDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/appstore/screenshots/\(language)", isDirectory: true)
    }

    /// Libellés par langue (sélecteurs d'onglets et de liens).
    private struct Labels {
        let printers: String
        let archives: String
        let queue: String
        let viewer: String
    }

    private var labels: Labels {
        switch language {
        case "en":
            Labels(
                printers: "Printers",
                archives: "Archives",
                queue: "Queue",
                viewer: "View G-code toolpath"
            )
        default:
            Labels(
                printers: "Imprimantes",
                archives: "Archives",
                queue: "File d’attente",
                viewer: "Voir le parcours G-code"
            )
        }
    }

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SCREENSHOT_CAPTURE"] == "1",
            "Captures App Store réservées au harnais (SCREENSHOT_CAPTURE=1)."
        )
        continueAfterFailure = true
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    private func launch() {
        app = XCUIApplication()
        app.launchArguments += [
            "-uitest-demo",
            "-uitest-appearance", appearance,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", language == "en" ? "en_US" : "fr_FR"
        ]
        app.launch()
    }

    func testCaptureAppStoreScreens() {
        let timeout: TimeInterval = 20
        launch()

        // Sélectionne le serveur de démo → coquille à onglets.
        let serverCell = app.cells.firstMatch
        XCTAssertTrue(serverCell.waitForExistence(timeout: timeout), "server cell")
        serverCell.tap()

        let l = labels

        // 01 — Accueil (tableau de bord + impression en cours).
        XCTAssertTrue(app.tabBars.buttons[l.printers].waitForExistence(timeout: timeout), "tab bar")
        sleep(4)
        capture("01-accueil")

        // 02 — Détail imprimante (cartes températures + AMS).
        app.tabBars.buttons[l.printers].tap()
        sleep(2)
        if tapFirstCell(timeout: timeout) {
            sleep(4)
            capture("02-detail-imprimante")
            goBack()
        }

        // 03 — Archives.
        app.tabBars.buttons[l.archives].tap()
        sleep(3)
        capture("03-archives")

        // 04 — Viewer 3D (depuis la première archive → lien parcours G-code).
        if tapFirstCell(timeout: timeout) {
            sleep(2)
            let viewerLink = app.buttons[l.viewer]
            if viewerLink.waitForExistence(timeout: timeout) {
                if viewerLink.isHittable {
                    viewerLink.tap()
                } else {
                    viewerLink.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                sleep(5) // laisse WebKit rendre le tracé
                capture("04-viewer-3d")
                goBack()
            }
            goBack()
        }

        // 05 — File d'attente.
        app.tabBars.buttons[l.queue].tap()
        sleep(3)
        capture("05-file-attente")
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
        attachment.name = "\(language)-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

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

    private func goBack() {
        let back = app.navigationBars.buttons.firstMatch
        if back.exists, back.isHittable {
            back.tap()
            sleep(1)
        }
    }
}
