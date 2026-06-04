// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Liens externes personnalisés du serveur : liste (ouvrables dans le navigateur), création,
/// suppression.
struct ExternalLinksView: View {
    @State private var model: ExternalLinksModel
    @State private var isCreating = false

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeExternalLinksModel(for: server))
    }

    var body: some View {
        List {
            ForEach(model.links) { link in
                row(for: link)
                    .listRowBackground(DSColor.card)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await model.delete(link) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("External links")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreating = true
                } label: {
                    Label("Add link", systemImage: "plus")
                }
            }
        }
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
        .sheet(isPresented: $isCreating) {
            ExternalLinkCreateSheet(model: model)
        }
    }

    @ViewBuilder
    private func row(for link: ExternalLink) -> some View {
        if let url = link.resolvedURL {
            Link(destination: url) {
                ExternalLinkRow(link: link)
            }
        } else {
            ExternalLinkRow(link: link)
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.links.isEmpty {
            ProgressView().tint(DSColor.accent)
        } else if model.links.isEmpty {
            if let error = model.loadError {
                ContentUnavailableView {
                    Label("Couldn’t load links", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No links",
                    systemImage: "link",
                    description: Text("Add a link to a wiki, store or documentation.")
                )
            }
        }
    }
}

private struct ExternalLinkRow: View {
    let link: ExternalLink

    var body: some View {
        HStack(spacing: DSSpacing.md) {
            Image(systemName: "link")
                .foregroundStyle(DSColor.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(link.name)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Text(link.url)
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "arrow.up.right.square")
                .foregroundStyle(DSColor.textSecondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, DSSpacing.xs)
        .accessibilityElement(children: .combine)
    }
}

/// Feuille de création d'un lien externe : nom + URL.
private struct ExternalLinkCreateSheet: View {
    let model: ExternalLinksModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var isSaving = false

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && URL(string: url.trimmingCharacters(in: .whitespaces))?.scheme != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Link") {
                    TextField("Name", text: $name)
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle("New link")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(DSColor.accent)
                    } else {
                        Button("Add") {
                            Task { await save() }
                        }
                        .disabled(!isValid)
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        await model.create(
            name: name.trimmingCharacters(in: .whitespaces),
            url: url.trimmingCharacters(in: .whitespaces)
        )
        isSaving = false
        dismiss()
    }
}
