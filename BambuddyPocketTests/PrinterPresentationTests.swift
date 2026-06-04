// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
@testable import BambuddyPocketDomain
@testable import BamPocket

@Suite("Présentation adaptative (Wi-Fi, AMS)")
struct PrinterPresentationTests {
    @Test("wifiSignal : qualité selon les seuils dBm")
    func wifiSignalQuality() {
        #expect(PrinterPresentation.wifiSignal(-29).contains("-29 dBm"))
        #expect(PrinterPresentation.wifiSignal(-29).contains(String(localized: "Excellent")))
        #expect(PrinterPresentation.wifiSignal(-55).contains(String(localized: "Good")))
        #expect(PrinterPresentation.wifiSignal(-65).contains(String(localized: "Fair")))
        #expect(PrinterPresentation.wifiSignal(-85).contains(String(localized: "Weak")))
    }

    @Test("AMSPresentation.title : libellé selon le type")
    func amsTitle() {
        #expect(AMSPresentation.title(kind: .standard, id: 0) == String(localized: "AMS 1"))
        #expect(AMSPresentation.title(kind: .amsLite, id: 0) == String(localized: "AMS Lite"))
        // L'AMS-HT (id matériel 128) est numérotée 1.
        #expect(AMSPresentation.title(kind: .ht, id: 128) == String(localized: "AMS-HT 1"))
    }
}
