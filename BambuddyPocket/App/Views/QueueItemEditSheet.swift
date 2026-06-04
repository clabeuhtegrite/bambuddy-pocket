// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Helpers de présentation de la file d'attente (formatage de la planification).
enum QueuePresentation {
    /// Date planifiée formatée pour l'affichage, ou `nil` si absente/illisible.
    static func scheduledLabel(_ raw: String?) -> String? {
        guard let raw, let date = parse(raw) else { return nil }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    /// Tente de décoder une date ISO-8601 (tolère le suffixe `+00:00Z` du serveur).
    static func parse(_ raw: String) -> Date? {
        // Le serveur sérialise parfois `2026-06-10T08:00:00+00:00Z` (suffixe Z superflu).
        let trimmed = raw.hasSuffix("+00:00Z") ? String(raw.dropLast()) : raw
        let parser = ISO8601DateFormatter()
        return parser.date(from: trimmed) ?? parser.date(from: raw)
    }
}

/// Feuille d'édition d'un élément en attente : planification, imprimante, démarrage manuel,
/// options d'impression. Mappe sur `PATCH /queue/{id}` (`QueueItemUpdate`).
struct QueueItemEditSheet: View {
    let item: QueueItem
    let printers: [Printer]
    let model: QueueListModel

    @Environment(\.dismiss) private var dismiss
    @State private var printerID: Int?
    @State private var scheduleEnabled: Bool
    @State private var scheduledDate: Date
    @State private var manualStart: Bool
    @State private var requirePreviousSuccess: Bool
    @State private var autoOffAfter: Bool
    @State private var bedLevelling: Bool
    @State private var timelapse: Bool
    @State private var useAms: Bool

    init(item: QueueItem, printers: [Printer], model: QueueListModel) {
        self.item = item
        self.printers = printers
        self.model = model
        _printerID = State(initialValue: item.printerId)
        let scheduled = item.scheduledTime.flatMap(QueuePresentation.parse)
        _scheduleEnabled = State(initialValue: scheduled != nil)
        _scheduledDate = State(initialValue: scheduled ?? Date().addingTimeInterval(3600))
        _manualStart = State(initialValue: item.manualStart ?? false)
        _requirePreviousSuccess = State(initialValue: item.requirePreviousSuccess ?? false)
        _autoOffAfter = State(initialValue: item.autoOffAfter ?? false)
        _bedLevelling = State(initialValue: item.bedLevelling ?? true)
        _timelapse = State(initialValue: item.timelapse ?? false)
        _useAms = State(initialValue: item.useAms ?? true)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Printer") {
                    Picker("Printer", selection: $printerID) {
                        Text("Any model").tag(Int?.none)
                        ForEach(printers) { printer in
                            Text(printer.name).tag(Int?.some(printer.id))
                        }
                    }
                }
                Section("Scheduling") {
                    Toggle("Schedule start", isOn: $scheduleEnabled)
                    if scheduleEnabled {
                        DatePicker("Start at", selection: $scheduledDate)
                    }
                    Toggle("Manual start", isOn: $manualStart)
                    Toggle("Require previous success", isOn: $requirePreviousSuccess)
                    Toggle("Power off when done", isOn: $autoOffAfter)
                }
                Section("Print options") {
                    Toggle("Bed levelling", isOn: $bedLevelling)
                    Toggle("Timelapse", isOn: $timelapse)
                    Toggle("Use AMS", isOn: $useAms)
                }
            }
            .dsListBackground()
            .navigationTitle("Edit queue item")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await model.update(item, with: makeUpdate()) }
                        dismiss()
                    }
                }
            }
        }
    }

    private func makeUpdate() -> QueueItemUpdate {
        QueueItemUpdate(
            printerId: printerID,
            scheduledTime: scheduleEnabled ? encodedSchedule() : nil,
            manualStart: manualStart,
            requirePreviousSuccess: requirePreviousSuccess,
            autoOffAfter: autoOffAfter,
            bedLevelling: bedLevelling,
            timelapse: timelapse,
            useAms: useAms
        )
    }

    private func encodedSchedule() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: scheduledDate)
    }
}
