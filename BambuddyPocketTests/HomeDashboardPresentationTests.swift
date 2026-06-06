// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

@Suite("Accueil — agrégation (instantanés, hero, alerte)")
struct HomeDashboardPresentationTests {
    /// Fabrique un statut d'impression active à une progression donnée.
    private func printingStatus(progress: Double, layer: Int = 10, total: Int = 100) -> PrinterStatus {
        var status = PrinterStatus()
        status.connected = true
        status.state = .running
        status.progress = progress
        status.layerNum = layer
        status.totalLayers = total
        return status
    }

    private func printer(_ id: Int, _ name: String) -> Printer {
        Printer(id: id, name: name)
    }

    @Test("snapshots : imprimantes en impression d'abord, les plus avancées en tête")
    func snapshotsOrdering() {
        let printers = [
            printer(1, "Zeta"),
            printer(2, "Alpha"),
            printer(3, "Beta")
        ]
        let statuses: [Int: PrinterStatus] = [
            1: printingStatus(progress: 30),
            3: printingStatus(progress: 70)
            // 2 (Alpha) : au repos (pas de statut → nil)
        ]
        let snapshots = HomeDashboardPresentation.snapshots(printers: printers) { statuses[$0.id] }

        // En tête : Beta (70 %) puis Zeta (30 %), puis les inactifs par nom (Alpha).
        #expect(snapshots.map(\.printer.name) == ["Beta", "Zeta", "Alpha"])
        #expect(HomeDashboardPresentation.printingCount(snapshots) == 2)
        #expect(HomeDashboardPresentation.heroSnapshot(snapshots)?.printer.name == "Beta")
    }

    @Test("heroSnapshot : nil si aucune impression active")
    func heroNilWhenIdle() {
        let printers = [printer(1, "Alpha")]
        let snapshots = HomeDashboardPresentation.snapshots(printers: printers) { _ in
            var status = PrinterStatus()
            status.connected = true
            status.state = .idle
            return status
        }
        #expect(HomeDashboardPresentation.heroSnapshot(snapshots) == nil)
    }

    @Test("alert : erreur HMS alarmante prioritaire sur une bobine faible")
    func alertPrioritizesHMS() {
        var printingWithError = printingStatus(progress: 40)
        // 0700_4001 (connu) + quartet de gravité 2 (serious) → alarmante (cf. logique #81 + filtrage connu).
        printingWithError.hmsErrors = [HMSError(code: "0x4001", attr: 0x0700_0200)]
        // Et une bobine faible sur la même imprimante.
        var lowUnit = AMSUnit(id: 0)
        var tray = AMSTray(id: 0)
        tray.trayType = "PLA"
        tray.remain = 5
        lowUnit.tray = [tray]
        printingWithError.ams = [lowUnit]

        let printers = [printer(1, "X2D")]
        let snapshots = HomeDashboardPresentation.snapshots(printers: printers) { _ in printingWithError }

        let alert = HomeDashboardPresentation.alert(snapshots)
        #expect(alert?.severity == .error)
    }

    @Test("alert : bobine AMS faible déclenche un avertissement")
    func alertLowFilament() {
        var status = PrinterStatus()
        status.connected = true
        status.state = .idle
        var unit = AMSUnit(id: 0)
        var tray = AMSTray(id: 2)
        tray.trayType = "PLA"
        tray.remain = 8
        unit.tray = [tray]
        status.ams = [unit]

        let snapshots = HomeDashboardPresentation.snapshots(printers: [printer(1, "Atelier")]) { _ in status }
        let alert = HomeDashboardPresentation.alert(snapshots)
        #expect(alert?.severity == .warning)
        // Slot 1-based : unit 0, tray id 2 → slot 3.
        #expect(alert?.detail.contains("3") == true)
    }

    @Test("alert : plateau non vidé porte le type et l'imprimante pour l'action directe (#2)")
    func alertPlateNotClearedCarriesAction() {
        var status = PrinterStatus()
        status.connected = true
        status.state = .finish
        status.awaitingPlateClear = true

        let snapshots = HomeDashboardPresentation.snapshots(printers: [printer(7, "Atelier")]) { _ in status }
        let alert = HomeDashboardPresentation.alert(snapshots)
        #expect(alert?.severity == .warning)
        #expect(alert?.kind == .plateNotCleared)
        // L'alerte référence l'imprimante concernée pour dispatcher le clear-plate.
        #expect(alert?.printerID == 7)
    }

    @Test("carte : nom du travail en impression, sinon nil ; bobines AMS chargées comptées (#3)")
    func cardJobAndSpoolCount() {
        var printing = printingStatus(progress: 50)
        printing.subtaskName = "Benchy"
        var unit = AMSUnit(id: 0)
        var loaded = AMSTray(id: 0)
        loaded.trayType = "PLA"
        loaded.remain = 80
        let empty = AMSTray(id: 1) // pas de type → non compté
        unit.tray = [loaded, empty]
        printing.ams = [unit]
        let printingSnap = PrinterSnapshot(printer: printer(1, "X2D"), status: printing)
        #expect(printingSnap.jobName == "Benchy")
        #expect(printingSnap.loadedSpoolCount == 1)

        var idle = PrinterStatus()
        idle.connected = true
        idle.state = .idle
        let idleSnap = PrinterSnapshot(printer: printer(2, "A1"), status: idle)
        #expect(idleSnap.jobName == nil)
        #expect(idleSnap.loadedSpoolCount == nil)
    }

    @Test("carte : résumé d'alerte priorisé (erreur > plateau > bobine basse), sinon nil (#3)")
    func cardAlertPriority() {
        // Erreur HMS prioritaire (même si le plateau attend aussi).
        var errored = printingStatus(progress: 20)
        errored.hmsErrors = [HMSError(code: "0x4001", attr: 0x0700_0200)]
        errored.awaitingPlateClear = true
        #expect(PrinterSnapshot(printer: printer(1, "E"), status: errored).cardAlert() == .hmsError)

        // Plateau non vidé (sans erreur).
        var plate = PrinterStatus()
        plate.connected = true
        plate.state = .finish
        plate.awaitingPlateClear = true
        #expect(PrinterSnapshot(printer: printer(2, "P"), status: plate).cardAlert() == .plateNotCleared)

        // Bobine basse (sans erreur ni plateau).
        var low = PrinterStatus()
        low.connected = true
        low.state = .idle
        var unit = AMSUnit(id: 0)
        var tray = AMSTray(id: 0)
        tray.trayType = "PLA"
        tray.remain = 5
        unit.tray = [tray]
        low.ams = [unit]
        #expect(PrinterSnapshot(printer: printer(3, "L"), status: low).cardAlert() == .lowFilament)

        // Statut sain → aucune alerte.
        var healthy = PrinterStatus()
        healthy.connected = true
        healthy.state = .idle
        #expect(PrinterSnapshot(printer: printer(4, "H"), status: healthy).cardAlert() == nil)
    }

    @Test("readyCount : connectée, au repos, sans erreur (ni en impression ni hors ligne)")
    func readyCountExcludesPrintingOfflineAndError() {
        let printers = [printer(1, "Ready"), printer(2, "Printing"), printer(3, "Offline"), printer(4, "Error")]
        var offline = PrinterStatus()
        offline.connected = false
        offline.state = .idle
        var errored = PrinterStatus()
        errored.connected = true
        errored.state = .idle
        errored.hmsErrors = [HMSError(code: "0x4001", attr: 0x0700_0200)]
        var ready = PrinterStatus()
        ready.connected = true
        ready.state = .idle
        let statuses: [Int: PrinterStatus] = [
            1: ready,
            2: printingStatus(progress: 50),
            3: offline,
            4: errored
        ]
        let snapshots = HomeDashboardPresentation.snapshots(printers: printers) { statuses[$0.id] }
        #expect(HomeDashboardPresentation.readyCount(snapshots) == 1)
    }

    @Test("alertCount : compte les imprimantes en alerte (erreur, plateau, bobine basse)")
    func alertCountCountsAlertingPrinters() {
        var errored = printingStatus(progress: 20)
        errored.hmsErrors = [HMSError(code: "0x4001", attr: 0x0700_0200)]
        var lowSpool = PrinterStatus()
        lowSpool.connected = true
        lowSpool.state = .idle
        var unit = AMSUnit(id: 0)
        var tray = AMSTray(id: 0)
        tray.trayType = "PLA"
        tray.remain = 5
        unit.tray = [tray]
        lowSpool.ams = [unit]
        var healthy = PrinterStatus()
        healthy.connected = true
        healthy.state = .idle
        let printers = [printer(1, "Err"), printer(2, "Low"), printer(3, "OK")]
        let statuses: [Int: PrinterStatus] = [1: errored, 2: lowSpool, 3: healthy]
        let snapshots = HomeDashboardPresentation.snapshots(printers: printers) { statuses[$0.id] }
        #expect(HomeDashboardPresentation.alertCount(snapshots) == 2)
    }

    @Test("alert : pas de fausse alarme (statut sain, slots pleins ou vides)")
    func alertNoFalseAlarm() {
        var status = PrinterStatus()
        status.connected = true
        status.state = .running
        status.progress = 50
        // Un slot plein (90 %) et un slot vide (sans type) → aucune alerte.
        var unit = AMSUnit(id: 0)
        var full = AMSTray(id: 0)
        full.trayType = "PETG"
        full.remain = 90
        let empty = AMSTray(id: 1) // pas de type → vide, ignoré
        unit.tray = [full, empty]
        status.ams = [unit]
        // Une erreur HMS **non** alarmante (informative) ne doit pas alarmer.
        status.hmsErrors = [HMSError(code: "0x0C00", attr: 0x0C00_0600, module: 12, severity: 0)]

        let snapshots = HomeDashboardPresentation.snapshots(printers: [printer(1, "Atelier")]) { _ in status }
        #expect(HomeDashboardPresentation.alert(snapshots) == nil)
    }

    // MARK: - Puissance smart-plug (retour device A7)

    private func plug(_ id: Int, printerID: Int?) -> SmartPlug {
        var plug = SmartPlug(id: id, name: "Plug \(id)")
        plug.printerID = printerID
        return plug
    }

    private func plugStatus(reachable: Bool, power: Double?) -> SmartPlugStatus {
        SmartPlugStatus(
            reachable: reachable,
            energy: power.map { SmartPlugEnergy(power: $0) }
        )
    }

    @Test("powerByPrinter : associe la puissance d'une prise joignable à son imprimante")
    func powerMapsReachablePlug() {
        let plugs = [plug(10, printerID: 1)]
        let statuses = [10: plugStatus(reachable: true, power: 42)]
        let map = HomeDashboardPresentation.powerByPrinter(plugs: plugs, statuses: statuses)
        #expect(map[1] == 42)
    }

    @Test("powerByPrinter : ignore prise sans imprimante, injoignable, ou sans mesure ; additionne")
    func powerIgnoresAndSums() {
        let plugs = [
            plug(10, printerID: 1), // joignable, 30 W
            plug(11, printerID: 1), // joignable, 12 W → addition sur l'imprimante 1
            plug(12, printerID: 2), // injoignable → ignorée
            plug(13, printerID: 3), // joignable mais sans mesure → ignorée
            plug(14, printerID: nil) // pas d'imprimante liée → ignorée
        ]
        let statuses: [Int: SmartPlugStatus] = [
            10: plugStatus(reachable: true, power: 30),
            11: plugStatus(reachable: true, power: 12),
            12: plugStatus(reachable: false, power: 99),
            13: plugStatus(reachable: true, power: nil)
        ]
        let map = HomeDashboardPresentation.powerByPrinter(plugs: plugs, statuses: statuses)
        #expect(map[1] == 42)
        #expect(map[2] == nil)
        #expect(map[3] == nil)
    }
}
