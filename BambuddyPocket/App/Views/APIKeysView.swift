// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Clés d'API du serveur : liste, création, révocation, suppression. Le secret complet d'une clé
/// créée n'est montré qu'une fois, dans une feuille dédiée.
struct APIKeysView: View {
    @State private var model: APIKeysModel
    @State private var isCreating = false

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeAPIKeysModel(for: server))
    }

    var body: some View {
        List {
            ForEach(model.keys) { key in
                APIKeyRow(key: key)
                    .listRowBackground(DSColor.card)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await model.delete(key) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            Task { await model.setEnabled(key, enabled: !key.isEnabled) }
                        } label: {
                            if key.isEnabled {
                                Label("Revoke", systemImage: "xmark.circle")
                            } else {
                                Label("Enable", systemImage: "checkmark.circle")
                            }
                        }
                        .tint(key.isEnabled ? DSColor.statusWarning : DSColor.statusOK)
                    }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("API keys")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            // Pas de bouton de création quand l'accès est refusé (clé d'API sur cet écran
            // d'administration) ou qu'aucune clé n'a pu être chargée : la création échouerait
            // de la même façon.
            if !showsLoadFailure {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreating = true
                    } label: {
                        Label("Create API key", systemImage: "plus")
                    }
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
            APIKeyCreateSheet(model: model)
        }
        .sheet(item: $model.createdSecret) { key in
            APIKeySecretSheet(key: key)
        }
    }

    /// Le chargement a échoué (403 admin requis ou autre erreur) et aucune clé n'est disponible :
    /// on n'affiche que l'état d'erreur, sans bouton de création.
    private var showsLoadFailure: Bool {
        model.keys.isEmpty && (model.isForbidden || model.loadError != nil)
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded, model.keys.isEmpty {
            ProgressView().tint(DSColor.accent)
        } else if model.isForbidden || (model.keys.isEmpty && model.loadError != nil) {
            CloudLoadFailureView(
                loadFailureTitle: "Couldn’t load API keys",
                isForbidden: model.isForbidden,
                loadError: model.loadError
            )
        } else if model.keys.isEmpty {
            ContentUnavailableView(
                "No API keys",
                systemImage: "key",
                description: Text("Create a key to grant programmatic access.")
            )
        }
    }
}

private struct APIKeyRow: View {
    let key: APIKey

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack {
                Text(key.name)
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                    .lineLimit(1)
                Spacer()
                DSStatusBadge(
                    key.isEnabled ? String(localized: "Active") : String(localized: "Revoked"),
                    intent: key.isEnabled ? .success : .neutral
                )
            }
            if let prefix = key.keyPrefix {
                Text(prefix)
                    .font(.caption.monospaced())
                    .foregroundStyle(DSColor.textSecondary)
            }
            Text(permissionsSummary)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.textSecondary)
        }
        .padding(.vertical, DSSpacing.xs)
    }

    private var permissionsSummary: String {
        var granted: [String] = []
        if key.canReadStatus ?? false {
            granted.append(String(localized: "Read status"))
        }
        if key.canQueue ?? false {
            granted.append(String(localized: "Queue"))
        }
        if key.canControlPrinter ?? false {
            granted.append(String(localized: "Control printer"))
        }
        if key.canAccessCloud ?? false {
            granted.append(String(localized: "Cloud"))
        }
        return granted.isEmpty ? String(localized: "No permissions") : granted.joined(separator: " · ")
    }
}

/// Feuille de création d'une clé d'API : nom + permissions.
private struct APIKeyCreateSheet: View {
    let model: APIKeysModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var canReadStatus = true
    @State private var canQueue = true
    @State private var canControlPrinter = false
    @State private var canAccessCloud = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                }
                Section("Permissions") {
                    Toggle("Read status", isOn: $canReadStatus)
                    Toggle("Queue", isOn: $canQueue)
                    Toggle("Control printer", isOn: $canControlPrinter)
                    Toggle("Cloud", isOn: $canAccessCloud)
                }
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle("New API key")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(DSColor.accent)
                    } else {
                        Button("Create") {
                            Task { await create() }
                        }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func create() async {
        isSaving = true
        await model.create(
            APIKeyCreate(
                name: name.trimmingCharacters(in: .whitespaces),
                canQueue: canQueue,
                canControlPrinter: canControlPrinter,
                canReadStatus: canReadStatus,
                canAccessCloud: canAccessCloud
            )
        )
        isSaving = false
        dismiss()
    }
}

/// Feuille affichant le secret complet de la clé créée (montré une seule fois).
private struct APIKeySecretSheet: View {
    let key: APIKey

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Copy this key now — it won’t be shown again.")
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textPrimary)
                }
                if let secret = key.secret {
                    Section("API key") {
                        Text(secret)
                            .font(.callout.monospaced())
                            .foregroundStyle(DSColor.textPrimary)
                            .textSelection(.enabled)
                        Button {
                            UIPasteboard.general.string = secret
                        } label: {
                            Label("Copy to clipboard", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
            .dsListBackground()
            .navigationTitle(key.name)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
