// SPDX-License-Identifier: AGPL-3.0-or-later
import Testing
@testable import BamPocket

/// Tests du **formateur de durée unique** (B2) partagé par `ArchivePresentation` et
/// `SupportPresentation`.
@Suite("Formatage de durée")
struct DurationPresentationTests {
    @Test("Heures et minutes au-delà d'une heure")
    func hoursAndMinutes() {
        #expect(DurationPresentation.string(seconds: 4800, showsSeconds: false) == "1 h 20 min")
        #expect(DurationPresentation.string(seconds: 4800, showsSeconds: true) == "1 h 20 min")
    }

    @Test("Minutes seules sous une heure")
    func minutesOnly() {
        #expect(DurationPresentation.string(seconds: 720, showsSeconds: false) == "12 min")
        #expect(DurationPresentation.string(seconds: 720, showsSeconds: true) == "12 min")
    }

    @Test("Sous la minute : secondes ou arrondi minute selon showsSeconds")
    func subMinute() {
        #expect(DurationPresentation.string(seconds: 45, showsSeconds: true) == "45 s")
        #expect(DurationPresentation.string(seconds: 45, showsSeconds: false) == "0 min")
    }

    @Test("Les secondes négatives sont traitées comme zéro")
    func negativeClampedToZero() {
        #expect(DurationPresentation.string(seconds: -10, showsSeconds: true) == "0 s")
        #expect(DurationPresentation.string(seconds: -10, showsSeconds: false) == "0 min")
    }

    @Test("ArchivePresentation.duration renvoie nil pour une durée absente ou nulle")
    func archiveReturnsNilForEmpty() {
        #expect(ArchivePresentation.duration(seconds: nil) == nil)
        #expect(ArchivePresentation.duration(seconds: 0) == nil)
        #expect(ArchivePresentation.duration(seconds: 720) == "12 min")
    }

    @Test("SupportPresentation.duration montre les secondes sous la minute")
    func supportShowsSeconds() {
        #expect(SupportPresentation.duration(seconds: 30) == "30 s")
        #expect(SupportPresentation.duration(seconds: 3900) == "1 h 5 min")
    }
}
