// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import SwiftUI

/// Feuille de création (`POST /projects/`) ou d'édition (`PATCH /projects/{id}`) d'un projet.
struct ProjectFormSheet: View {
    let model: ProjectListModel
    let editing: Project?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var description: String
    @State private var notes: String
    @State private var tags: String
    @State private var url: String
    @State private var priority: String
    @State private var targetEnabled: Bool
    @State private var targetCount: Int
    @State private var status: String

    private let priorities = ["low", "normal", "high"]
    private let statuses = ["active", "completed", "archived"]

    init(model: ProjectListModel, editing: Project? = nil) {
        self.model = model
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _description = State(initialValue: editing?.details ?? "")
        _notes = State(initialValue: editing?.notes ?? "")
        _tags = State(initialValue: editing?.tags ?? "")
        _url = State(initialValue: editing?.url ?? "")
        _priority = State(initialValue: editing?.priority ?? "normal")
        _targetEnabled = State(initialValue: editing?.targetCount != nil)
        _targetCount = State(initialValue: editing?.targetCount ?? 10)
        _status = State(initialValue: editing?.status ?? "active")
    }

    private var isEditing: Bool {
        editing != nil
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Project name", text: $name)
                }
                Section("Details") {
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2 ... 4)
                    Picker("Priority", selection: $priority) {
                        ForEach(priorities, id: \.self) { value in
                            Text(value.capitalized).tag(value)
                        }
                    }
                    if isEditing {
                        Picker("Status", selection: $status) {
                            ForEach(statuses, id: \.self) { value in
                                Text(value.capitalized).tag(value)
                            }
                        }
                    }
                    Toggle("Set target", isOn: $targetEnabled)
                    if targetEnabled {
                        Stepper("Target: \(targetCount)", value: $targetCount, in: 1 ... 1000)
                    }
                }
                Section("Notes") {
                    TextField("Tags (comma-separated)", text: $tags)
                        .textInputAutocapitalization(.never)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2 ... 5)
                    TextField("External URL", text: $url)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle(isEditing ? "Edit project" : "New project")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        Task { await submit() }
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func submit() async {
        let trimmedTags = tags.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = targetEnabled ? targetCount : nil
        if let editing {
            await model.update(
                editing,
                with: ProjectUpdate(
                    name: trimmedName,
                    description: description,
                    status: status,
                    targetCount: target,
                    notes: notes,
                    tags: trimmedTags,
                    priority: priority,
                    url: trimmedURL
                )
            )
        } else {
            _ = await model.create(
                ProjectCreate(
                    name: trimmedName,
                    description: description,
                    targetCount: target,
                    notes: notes,
                    tags: trimmedTags,
                    priority: priority,
                    url: trimmedURL
                )
            )
        }
    }
}
