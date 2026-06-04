// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Réglages serveur : langue, devise, imprimante par défaut, coûts. Les modifications sont
/// envoyées via `PATCH /settings/` au bouton « Enregistrer » (seuls les champs modifiés partent).
struct SettingsView: View {
    @State private var model: SettingsModel
    @State private var editor = SettingsEditor()
    @State private var hasSeeded = false

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeSettingsModel(for: server))
    }

    var body: some View {
        List {
            if model.settings != nil {
                generalSection
                defaultPrinterSection
                costsSection
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if model.isSaving {
                    ProgressView().tint(DSColor.accent)
                } else {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(model.settings == nil || !editor.hasChanges)
                }
            }
        }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
            seedIfNeeded()
        }
    }

    private var generalSection: some View {
        Section("General") {
            Picker("Language", selection: $editor.language) {
                ForEach(SettingsEditor.languages, id: \.code) { entry in
                    Text(entry.label).tag(entry.code)
                }
            }
            Picker("Currency", selection: $editor.currency) {
                ForEach(SettingsEditor.currencies, id: \.self) { code in
                    Text(code).tag(code)
                }
            }
        }
    }

    private var defaultPrinterSection: some View {
        Section {
            Picker("Default printer", selection: $editor.defaultPrinterID) {
                Text("None").tag(Int?.none)
                ForEach(model.printers) { printer in
                    Text(printer.name).tag(Int?.some(printer.id))
                }
            }
        } footer: {
            Text("Used as the default target when adding prints to the queue.")
        }
    }

    private var costsSection: some View {
        Section("Costs") {
            LabeledContent("Filament cost (per kg)") {
                TextField("0", value: $editor.defaultFilamentCost, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Energy cost (per kWh)") {
                TextField("0", value: $editor.energyCostPerKwh, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.settings == nil {
            ProgressView().tint(DSColor.accent)
        } else if model.settings == nil, let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t load settings", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        }
    }

    private func seedIfNeeded() {
        guard !hasSeeded, let settings = model.settings else {
            return
        }
        editor.seed(from: settings)
        hasSeeded = true
    }

    private func save() async {
        guard let original = model.settings else {
            return
        }
        await model.apply(editor.update(comparedTo: original))
        if let refreshed = model.settings {
            editor.seed(from: refreshed)
        }
    }
}

/// État éditable des réglages, séparé du modèle réseau pour un binding propre des champs.
struct SettingsEditor {
    var language = "en"
    var currency = "USD"
    var defaultPrinterID: Int?
    var defaultFilamentCost: Double = 0
    var energyCostPerKwh: Double = 0

    private var seeded = AppSettings()

    static let languages: [(code: String, label: String)] = [
        ("en", "English"),
        ("fr", "Français"),
        ("es", "Español"),
        ("de", "Deutsch")
    ]

    static let currencies = ["USD", "EUR", "GBP", "CHF", "CAD", "AUD", "JPY", "CNY"]

    mutating func seed(from settings: AppSettings) {
        seeded = settings
        language = settings.language ?? "en"
        currency = settings.currency ?? "USD"
        defaultPrinterID = settings.defaultPrinterID
        defaultFilamentCost = settings.defaultFilamentCost ?? 0
        energyCostPerKwh = settings.energyCostPerKwh ?? 0
    }

    /// Y a-t-il une modification par rapport à la dernière valeur chargée ?
    var hasChanges: Bool {
        language != (seeded.language ?? "en")
            || currency != (seeded.currency ?? "USD")
            || defaultPrinterID != seeded.defaultPrinterID
            || defaultFilamentCost != (seeded.defaultFilamentCost ?? 0)
            || energyCostPerKwh != (seeded.energyCostPerKwh ?? 0)
    }

    /// Construit une mise à jour ne contenant que les champs réellement modifiés.
    func update(comparedTo original: AppSettings) -> AppSettingsUpdate {
        var update = AppSettingsUpdate()
        if language != (original.language ?? "en") {
            update.language = language
        }
        if currency != (original.currency ?? "USD") {
            update.currency = currency
        }
        if defaultPrinterID != original.defaultPrinterID {
            update.defaultPrinterID = defaultPrinterID
        }
        if defaultFilamentCost != (original.defaultFilamentCost ?? 0) {
            update.defaultFilamentCost = defaultFilamentCost
        }
        if energyCostPerKwh != (original.energyCostPerKwh ?? 0) {
            update.energyCostPerKwh = energyCostPerKwh
        }
        return update
    }
}
