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

    /// Parcours complet : état vide → ajout d'un serveur → détail → imprimantes → notifications.
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

        // 5) Ouvre le détail serveur (titre = libellé du serveur). Le lien « Printers » est en
        // haut de la liste — repère fiable de l'écran de détail (les sections plus bas, comme
        // « Test connection », ne sont pas garanties dans l'arbre d'accessibilité sans défilement).
        tap(serverCell)
        XCTAssertTrue(
            app.navigationBars["Atelier"].waitForExistence(timeout: timeout),
            "Le détail serveur doit s'ouvrir (titre = libellé)."
        )

        // 6) Navigue vers les imprimantes : on tape la **cellule** « Printers » (un NavigationLink
        // de la liste) pour déclencher la navigation, puis on vérifie la barre « Printers ».
        // Chaque NavigationLink est exposé comme un Button (libellé = titre de la ligne).
        let printersButton = app.buttons["Printers"]
        XCTAssertTrue(
            printersButton.waitForExistence(timeout: timeout),
            "Le détail serveur doit présenter la ligne « Printers »."
        )
        tap(printersButton)
        // L'écran Imprimantes porte le libellé du serveur comme titre ; on l'identifie via son
        // bouton « Add printer » (unique à cet écran).
        XCTAssertTrue(
            app.buttons["Add printer"].waitForExistence(timeout: timeout),
            "L'écran Imprimantes doit s'ouvrir (bouton « Add printer »)."
        )

        // Reviens au détail serveur (le lien « Printers » réapparaît dans la liste).
        goBack()
        XCTAssertTrue(
            app.buttons["Printers"].waitForExistence(timeout: timeout),
            "Retour au détail serveur attendu."
        )

        // 7) Ouvre le centre de notifications (cloche dans la barre) puis le referme.
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
