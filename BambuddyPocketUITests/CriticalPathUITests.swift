// SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest

/// Tests XCUITest des parcours critiques, **fiables en CI** (aucune dépendance à un backend
/// Bambuddy en marche). L'app est lancée **sans** `-uitest-seed` : on part d'une liste de serveurs
/// vide, on ajoute un serveur via le formulaire, puis on vérifie la navigation et le chrome des
/// écrans (titres, liens, barres de navigation, feuilles). Les écrans de données s'affichent en
/// état vide/chargement faute de backend — on n'asserte donc que sur la **structure**, pas sur des
/// données réseau, ce qui garde les tests déterministes.
///
/// Locale : forcée en anglais ; les sélecteurs utilisent les libellés sources anglais.
@MainActor
final class CriticalPathUITests: XCTestCase {
    private var app: XCUIApplication!
    private let timeout: TimeInterval = 20

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Pas de seed : on veut une liste vide reproductible, indépendante de tout état persistant.
        // Locale forcée en anglais pour que les sélecteurs (libellés sources) soient déterministes
        // quel que soit le réglage du simulateur.
        app.launchArguments += [
            "-uitest-fresh",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    /// Parcours complet : état vide → ajout d'un serveur → coquille à onglets → Accueil →
    /// onglet Imprimantes → onglet Plus → notifications.
    func testAddServerThenNavigateToPrintersAndNotifications() {
        // 1) État vide : l'invite « Add server » est présente.
        let addServerButtons = app.buttons["Add server"]
        XCTAssertTrue(
            addServerButtons.firstMatch.waitForExistence(timeout: timeout),
            "L'invite d'ajout de serveur doit apparaître sur une liste vide."
        )

        // 2) Ouvre le formulaire d'ajout et renseigne URL + libellé.
        addServerButtons.firstMatch.tap()

        let urlField = app.textFields["Server URL"]
        XCTAssertTrue(urlField.waitForExistence(timeout: timeout), "Champ URL du serveur.")
        urlField.tap()
        urlField.typeText("http://printer.local:8000")

        let labelField = app.textFields["Label"]
        XCTAssertTrue(labelField.waitForExistence(timeout: 5), "Champ libellé du serveur.")
        labelField.tap()
        labelField.typeText("Atelier")

        // 3) Enregistre : le bouton Save existe et déclenche le retour à la liste.
        let saveButton = app.buttons["Save"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5), "Bouton Enregistrer.")
        saveButton.tap()

        // 4) Le serveur ajouté apparaît dans la liste (libellé « Atelier »).
        let serverCell = app.cells.firstMatch
        XCTAssertTrue(
            serverCell.waitForExistence(timeout: timeout),
            "Le serveur enregistré doit apparaître dans la liste."
        )

        // 5) Sélectionne le serveur : la coquille à onglets s'ouvre sur l'onglet Accueil (titre =
        // libellé du serveur).
        tap(serverCell)
        XCTAssertTrue(
            app.navigationBars["Atelier"].waitForExistence(timeout: timeout),
            "L'onglet Accueil doit s'ouvrir (titre = libellé du serveur)."
        )
        // L'onglet Accueil expose un bouton « Servers » (retour multi-serveurs) — repère fiable.
        XCTAssertTrue(
            app.buttons["Servers"].waitForExistence(timeout: timeout),
            "L'accueil doit présenter le bouton de retour à la liste des serveurs."
        )

        // 6) Bascule sur l'onglet « Printers » via la barre d'onglets, puis vérifie l'écran.
        let printersTab = app.tabBars.buttons["Printers"]
        XCTAssertTrue(printersTab.waitForExistence(timeout: timeout), "Onglet Imprimantes.")
        printersTab.tap()
        XCTAssertTrue(
            app.buttons["Add printer"].waitForExistence(timeout: timeout),
            "L'écran Imprimantes doit s'ouvrir (bouton « Add printer »)."
        )

        // 7) Bascule sur l'onglet « More » : sections groupées (« Production », etc.).
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: timeout), "Onglet Plus.")
        moreTab.tap()
        XCTAssertTrue(
            app.staticTexts["PRODUCTION"].waitForExistence(timeout: timeout)
                || app.buttons["Print queue"].waitForExistence(timeout: timeout),
            "L'onglet Plus doit présenter les sections groupées."
        )

        // 8) Ouvre le centre de notifications depuis l'accueil (cloche dans la barre) puis referme.
        app.tabBars.buttons["Home"].tap()
        let notifications = app.buttons["Notifications"]
        if notifications.waitForExistence(timeout: 5) {
            notifications.tap()
            XCTAssertTrue(
                app.navigationBars["Notifications"].waitForExistence(timeout: timeout),
                "Le centre de notifications doit s'ouvrir."
            )
            tapIfExists(app.buttons["Done"])
        }
    }

    /// Parcours secondaire : l'écran « About » est accessible depuis la liste des serveurs et
    /// affiche ses informations (version, licence).
    func testAboutScreenIsReachable() {
        let about = app.buttons["About"]
        XCTAssertTrue(about.waitForExistence(timeout: timeout), "Bouton À propos dans la barre.")
        about.tap()

        XCTAssertTrue(
            app.navigationBars["About"].waitForExistence(timeout: timeout),
            "L'écran À propos doit s'ouvrir."
        )
        XCTAssertTrue(
            app.staticTexts["Version"].waitForExistence(timeout: 5),
            "L'écran À propos doit afficher la version."
        )
        // Crédits open source : la section et au moins un composant (three.js) sont présents.
        XCTAssertTrue(
            app.staticTexts["Open source components"].waitForExistence(timeout: 5),
            "L'écran À propos doit présenter les crédits open source."
        )
        XCTAssertTrue(
            app.staticTexts["three.js"].waitForExistence(timeout: 5),
            "Les crédits doivent lister three.js."
        )
        tapIfExists(app.buttons["Done"])
        // De retour à la liste : le bouton d'ajout est de nouveau visible.
        XCTAssertTrue(
            app.buttons["Add server"].firstMatch.waitForExistence(timeout: timeout),
            "Retour à la liste des serveurs attendu."
        )
    }

    /// Parcours d'annulation : le formulaire d'ajout peut être ouvert puis annulé sans créer de
    /// serveur (la liste reste vide).
    func testAddServerCancelKeepsListEmpty() {
        let addServer = app.buttons["Add server"].firstMatch
        XCTAssertTrue(addServer.waitForExistence(timeout: timeout), "Invite d'ajout.")
        addServer.tap()

        XCTAssertTrue(
            app.textFields["Server URL"].waitForExistence(timeout: timeout),
            "Le formulaire d'ajout doit s'ouvrir."
        )
        app.buttons["Cancel"].tap()

        // La liste reste à l'état vide (l'invite d'ajout est toujours là).
        XCTAssertTrue(
            app.buttons["Add server"].firstMatch.waitForExistence(timeout: timeout),
            "La liste doit rester vide après annulation."
        )
    }

    // MARK: Helpers

    private func goBack() {
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 5), back.isHittable {
            back.tap()
        }
    }

    private func tapIfExists(_ element: XCUIElement) {
        if element.waitForExistence(timeout: 3), element.isHittable {
            element.tap()
        }
    }

    /// Tape un élément, avec repli en coordonnées s'il n'est pas directement « hittable ».
    private func tap(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
