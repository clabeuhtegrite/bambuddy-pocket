// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
@testable import BambuddyPocketDomain

@Suite("QueueItem")
struct QueueItemTests {
    @Test("Décode un sous-ensemble de PrintQueueItemResponse")
    func decodesSubset() throws {
        let json = #"""
        {"id":5,"position":2,"status":"printing","printer_name":"X1C","archive_name":"Gear",
         "print_time_seconds":3600,"been_jumped":false}
        """#
        let data = try #require(json.data(using: .utf8))
        let item = try JSONDecoder.bambuddy().decode(QueueItem.self, from: data)
        #expect(item.id == 5)
        #expect(item.position == 2)
        #expect(item.status == "printing")
        #expect(item.printerName == "X1C")
        #expect(item.displayName == "Gear")
        #expect(item.printTimeSeconds == 3600)
    }

    @Test("displayName retombe sur le fichier de bibliothèque puis sur #id")
    func displayNameFallback() {
        var item = QueueItem(id: 9, position: 1, status: "pending")
        #expect(item.displayName == "#9")
        item.libraryFileName = "bracket.3mf"
        #expect(item.displayName == "bracket.3mf")
    }

    @Test("Décode les champs éditables d'une réponse réelle (Docker)")
    func decodesEditableFields() throws {
        let json = #"""
        {"id":2,"printer_id":1,"archive_id":1,"position":1,"scheduled_time":"2026-06-10T08:00:00Z",
         "require_previous_success":false,"auto_off_after":false,"manual_start":true,"bed_levelling":true,
         "flow_cali":false,"vibration_cali":true,"layer_inspect":false,"timelapse":false,"use_ams":true,
         "status":"pending","printer_name":"VP-Test","batch_id":1,"batch_name":"Test Cube ×3"}
        """#
        let data = try #require(json.data(using: .utf8))
        let item = try JSONDecoder.bambuddy().decode(QueueItem.self, from: data)
        #expect(item.printerId == 1)
        #expect(item.scheduledTime == "2026-06-10T08:00:00Z")
        #expect(item.manualStart == true)
        #expect(item.vibrationCali == true)
        #expect(item.batchId == 1)
        #expect(item.batchName == "Test Cube ×3")
    }

    @Test("QueueItemUpdate omet les champs nil à l'encodage")
    func updateOmitsNilFields() throws {
        let update = QueueItemUpdate(scheduledTime: "2026-06-10T08:00:00Z", manualStart: true)
        let data = try JSONEncoder.bambuddy().encode(update)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["scheduled_time"] as? String == "2026-06-10T08:00:00Z")
        #expect(json["manual_start"] as? Bool == true)
        #expect(json.keys.contains("printer_id") == false)
        #expect(json.keys.contains("use_ams") == false)
    }

    @Test("Décode un lot (PrintBatch) avec compteurs dérivés")
    func decodesBatch() throws {
        let json = #"""
        {"id":1,"name":"Test Cube ×3","quantity":3,"status":"active","archive_id":1,
         "pending_count":2,"printing_count":0,"completed_count":1,"failed_count":0,"cancelled_count":0}
        """#
        let data = try #require(json.data(using: .utf8))
        let batch = try JSONDecoder.bambuddy().decode(PrintBatch.self, from: data)
        #expect(batch.name == "Test Cube ×3")
        #expect(batch.quantity == 3)
        #expect(batch.pendingCount == 2)
        #expect(batch.resolvedCount == 1)
        #expect(batch.isFullyResolved == false)
        #expect(batch.displayStatus == "active") // En cours → on garde le statut serveur.
    }

    @Test("Un lot « active » obsolète mais tout annulé s'affiche « cancelled »")
    func batchStatusDerivedWhenResolved() {
        // Reproduit la prod : status « active » alors que 2/2 sont annulés (0 en attente).
        let batch = PrintBatch(
            id: 1,
            name: "HRC Clamp ×2",
            quantity: 2,
            status: "active",
            pendingCount: 0,
            printingCount: 0,
            completedCount: 0,
            failedCount: 0,
            cancelledCount: 2
        )
        #expect(batch.isFullyResolved == true)
        #expect(batch.displayStatus == "cancelled")
    }

    @Test("displayStatus dérive « completed » / « failed » selon les compteurs")
    func batchStatusVariants() {
        let completed = PrintBatch(
            id: 2, name: "x", quantity: 2, status: "active",
            completedCount: 2
        )
        #expect(completed.displayStatus == "completed")
        let failed = PrintBatch(
            id: 3, name: "x", quantity: 1, status: "active",
            failedCount: 1
        )
        #expect(failed.displayStatus == "failed")
    }

    @Test("Lot annulé : barre vide (rien d'abouti), jamais pleine et « terminée »")
    func cancelledBatchProgressIsEmpty() {
        // Le bug : « 2/2 terminés » + barre verte pleine pour un lot annulé.
        let batch = PrintBatch(
            id: 1, name: "HRC Clamp ×2", quantity: 2, status: "active",
            pendingCount: 0, printingCount: 0, completedCount: 0, failedCount: 0, cancelledCount: 2
        )
        #expect(batch.isCancelled == true)
        // resolvedCount vaut 2 (tous résolus) mais aucune réussite → barre vide.
        #expect(batch.resolvedCount == 2)
        #expect(batch.progressFraction == 0)
    }

    @Test("Lot mixte (réussites + annulations) : statut « completed », barre pleine cohérente")
    func mixedCompletedAndCancelled() {
        let batch = PrintBatch(
            id: 2, name: "x", quantity: 4, status: "active",
            completedCount: 1, cancelledCount: 3
        )
        // Dès qu'il reste une réussite, ce n'est pas un lot « annulé » : displayStatus = completed.
        // La barre suit alors les éléments résolus (cohérente avec le badge « Terminé »).
        #expect(batch.isFullyResolved == true)
        #expect(batch.isCancelled == false)
        #expect(batch.displayStatus == "completed")
        #expect(batch.progressFraction == 1)
    }

    @Test("Lot terminé avec succès : barre pleine")
    func completedBatchProgressIsFull() {
        let batch = PrintBatch(id: 3, name: "x", quantity: 2, status: "active", completedCount: 2)
        #expect(batch.isCancelled == false)
        #expect(batch.progressFraction == 1)
    }

    @Test("Lot en cours : la barre suit les éléments résolus")
    func inProgressBatchProgress() {
        let batch = PrintBatch(
            id: 4, name: "x", quantity: 4, status: "active",
            pendingCount: 2, printingCount: 0, completedCount: 1, cancelledCount: 1
        )
        #expect(batch.isFullyResolved == false)
        #expect(batch.isCancelled == false)
        // En cours : annulés + réussis comptent comme « traités » pour que la barre avance.
        #expect(batch.progressFraction == 0.5)
    }

    @Test("displayPosition : masquée pour les éléments terminaux, affichée sinon")
    func positionHiddenForTerminalItems() {
        var pending = QueueItem(id: 1, position: 3, status: "pending")
        #expect(pending.displayPosition == 3)
        pending.status = "printing"
        #expect(pending.displayPosition == 3)

        for terminal in ["completed", "failed", "cancelled"] {
            let item = QueueItem(id: 2, position: 1, status: terminal)
            #expect(item.isTerminal == true)
            #expect(item.displayPosition == nil)
        }
    }
}
