// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Détail d'un fichier de bibliothèque : métadonnées, notes, ajout à la file, édition.
struct LibraryFileDetailView: View {
    let file: LibraryFile
    let model: LibraryListModel

    @State private var isEditing = false
    @State private var showAdded = false
    @State private var printModel: PrintDispatchModel?

    /// Fichier à jour depuis le view-model (reflète les éditions), sinon l'instance passée.
    private var current: LibraryFile {
        model.files.first { $0.id == file.id } ?? file
    }

    var body: some View {
        List {
            if current.isSliced {
                Section {
                    Button {
                        printModel = model.makePrintDispatchModel(for: current)
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                    Button {
                        Task {
                            if await model.enqueue(current) {
                                showAdded = true
                            }
                        }
                    } label: {
                        Label("Add to queue", systemImage: "text.append")
                    }
                }
            }
            Section("File") {
                LabeledContent("Filename", value: current.filename)
                if let type = current.fileType {
                    LabeledContent("Type", value: type.uppercased())
                }
                if let size = current.fileSize {
                    LabeledContent("Size", value: Int64(size).formatted(.byteCount(style: .file)))
                }
                if let model = current.slicedForModel {
                    LabeledContent("Sliced for", value: model)
                }
                if let count = current.printCount, count > 0 {
                    LabeledContent("Prints", value: "\(count)")
                }
            }
            metadataSection
            notesSection
        }
        .dsListBackground()
        .navigationTitle(current.displayName)
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditing = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            LibraryFileEditSheet(file: current, model: model)
        }
        .sheet(item: $printModel) { printModel in
            PrintSheet(model: printModel)
        }
        .alert("Added to queue", isPresented: $showAdded) {
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    private var metadataSection: some View {
        let file = current
        if file.printTimeSeconds != nil || file.filamentUsedGrams != nil {
            Section("Estimate") {
                if let time = ArchivePresentation.duration(seconds: file.printTimeSeconds) {
                    LabeledContent("Print time", value: time)
                }
                if let filament = ArchivePresentation.filament(grams: file.filamentUsedGrams) {
                    LabeledContent("Filament", value: filament)
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if let notes = current.notes, !notes.isEmpty {
            Section("Notes") {
                Text(notes)
            }
        }
    }
}

/// Feuille d'édition d'un fichier : nom et notes (`PUT /library/files/{id}`).
struct LibraryFileEditSheet: View {
    let file: LibraryFile
    let model: LibraryListModel

    @Environment(\.dismiss) private var dismiss
    @State private var filename: String
    @State private var notes: String

    init(file: LibraryFile, model: LibraryListModel) {
        self.file = file
        self.model = model
        _filename = State(initialValue: file.filename)
        _notes = State(initialValue: file.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Filename", text: $filename)
                        .textInputAutocapitalization(.never)
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3 ... 6)
                }
            }
            .dsListBackground()
            .navigationTitle("Edit file")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await model.update(
                                file,
                                with: LibraryFileUpdate(
                                    filename: filename.trimmingCharacters(in: .whitespacesAndNewlines),
                                    notes: notes
                                )
                            )
                        }
                        dismiss()
                    }
                    .disabled(filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
