// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import SwiftUI

/// Feuille d'édition des métadonnées d'une archive : nom, étiquettes, notes, lien externe,
/// favori. Mappe sur `PATCH /archives/{id}` (`ArchiveUpdate`).
struct ArchiveEditSheet: View {
    let archive: Archive
    let model: ArchiveListModel

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var tags: String
    @State private var notes: String
    @State private var externalURL: String
    @State private var isFavorite: Bool

    init(archive: Archive, model: ArchiveListModel) {
        self.archive = archive
        self.model = model
        _name = State(initialValue: archive.printName ?? "")
        _tags = State(initialValue: archive.tags ?? "")
        _notes = State(initialValue: archive.notes ?? "")
        _externalURL = State(initialValue: archive.externalUrl ?? "")
        _isFavorite = State(initialValue: archive.isFavorite ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Print name", text: $name)
                }
                Section {
                    TextField("Comma-separated tags", text: $tags)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Separate tags with commas.")
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3 ... 6)
                }
                Section("Link") {
                    TextField("External URL", text: $externalURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
                Section {
                    Toggle("Favorite", isOn: $isFavorite)
                }
            }
            .navigationTitle("Edit archive")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await model.update(archive, with: makeUpdate()) }
                        dismiss()
                    }
                }
            }
        }
    }

    private func makeUpdate() -> ArchiveUpdate {
        ArchiveUpdate(
            printName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes,
            isFavorite: isFavorite,
            externalUrl: externalURL.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
