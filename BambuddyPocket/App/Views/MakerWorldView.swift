// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Intégration **MakerWorld** : état (capacité d'import), imports récents, et résolution d'une URL
/// publique en plates importables. L'import télécharge un 3MF côté serveur → bouton **gardé**
/// derrière `canImport` et une confirmation. Gardé admin → message « connexion admin requise ».
struct MakerWorldView: View {
    @State private var model: MakerWorldModel
    @State private var urlText = ""
    @State private var pendingImport: MakerWorldInstance?
    @State private var confirmingModelImport = false

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeMakerWorldModel(for: server))
    }

    private var showsLoadFailure: Bool {
        model.status == nil && (model.isForbidden || model.isUnavailable || model.loadError != nil)
    }

    var body: some View {
        List {
            if !showsLoadFailure {
                statusSection
                resolveSection
                if let resolved = model.resolved {
                    resolvedSection(resolved)
                }
                if !model.recentImports.isEmpty {
                    recentSection
                }
                if let message = model.actionMessage {
                    Section { Text(message).font(DSFont.caption).foregroundStyle(DSColor.textSecondary) }
                }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("MakerWorld")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
        .confirmationDialog(
            "Import to library?",
            isPresented: importConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Import") {
                let instanceId = pendingImport?.instanceId
                pendingImport = nil
                confirmingModelImport = false
                Task { await model.importPlate(instanceId: instanceId) }
            }
            Button("Cancel", role: .cancel) {
                pendingImport = nil
                confirmingModelImport = false
            }
        } message: {
            Text("This downloads the model into your server library.")
        }
    }

    /// Une confirmation est demandée soit pour une plate précise, soit pour le modèle entier.
    private var importConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingImport != nil || confirmingModelImport },
            set: { newValue in
                if !newValue {
                    pendingImport = nil
                    confirmingModelImport = false
                }
            }
        )
    }

    private var statusSection: some View {
        Section("Status") {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: model.canImport ? "checkmark.icloud" : "icloud.slash")
                    .foregroundStyle(model.canImport ? DSColor.statusOK : DSColor.textSecondary)
                    .accessibilityHidden(true)
                Text(model.canImport ? "Ready to import" : "Bambu Cloud token required")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
        }
    }

    private var resolveSection: some View {
        Section("Resolve a model") {
            TextField("MakerWorld URL", text: $urlText)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button {
                Task { await model.resolve(url: urlText) }
            } label: {
                HStack {
                    Text("Resolve")
                    Spacer()
                    if model.isResolving { ProgressView() }
                }
            }
            .disabled(urlText.trimmingCharacters(in: .whitespaces).isEmpty || model.isResolving)
        }
    }

    private func resolvedSection(_ resolved: MakerWorldResolvedModel) -> some View {
        Section {
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(resolved.design.title ?? String(localized: "Model \(resolved.modelId)"))
                    .font(DSFont.headline)
                    .foregroundStyle(DSColor.textPrimary)
                if let designer = resolved.design.designer, !designer.isEmpty {
                    Text(designer).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
                }
            }
            .padding(.vertical, DSSpacing.xs)
            if resolved.instances.isEmpty {
                importModelButton(resolved)
            } else {
                ForEach(resolved.instances) { instance in
                    instanceRow(instance, alreadyImported: false)
                }
            }
        } header: {
            Text("Resolved model")
        } footer: {
            if !model.canImport {
                Text("Importing requires a Bambu Cloud token on the server.").font(DSFont.caption)
            }
        }
    }

    private func instanceRow(_ instance: MakerWorldInstance, alreadyImported _: Bool) -> some View {
        HStack {
            Text(instance.name ?? String(localized: "Plate \(instance.instanceId)"))
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
            Spacer()
            Button("Import") {
                pendingImport = instance
            }
            .buttonStyle(.borderless)
            .disabled(!model.canImport || model.isImporting)
        }
    }

    private func importModelButton(_: MakerWorldResolvedModel) -> some View {
        Button {
            confirmingModelImport = true
        } label: {
            HStack {
                Label("Import model", systemImage: "square.and.arrow.down")
                Spacer()
                if model.isImporting { ProgressView() }
            }
        }
        .disabled(!model.canImport || model.isImporting)
    }

    private var recentSection: some View {
        Section("Recent imports") {
            ForEach(model.recentImports) { item in
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(item.filename).font(DSFont.body).foregroundStyle(DSColor.textPrimary)
                    if let source = item.sourceUrl, !source.isEmpty {
                        Text(source).font(DSFont.caption).foregroundStyle(DSColor.textSecondary).lineLimit(1)
                    }
                }
                .padding(.vertical, DSSpacing.xs)
                .listRowBackground(DSColor.card)
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else {
            CloudLoadFailureView(
                loadFailureTitle: "Couldn’t load MakerWorld",
                isForbidden: model.isForbidden,
                isUnavailable: model.isUnavailable,
                loadError: showsLoadFailure ? model.loadError : nil
            )
        }
    }
}

#Preview {
    NavigationStack {
        MakerWorldView(
            server: ServerConfiguration(
                label: "Atelier",
                baseURL: URL(string: "http://192.168.1.50:8000") ?? URL(filePath: "/")
            ),
            serverList: ServerListModel(environment: .inMemory())
        )
    }
}
