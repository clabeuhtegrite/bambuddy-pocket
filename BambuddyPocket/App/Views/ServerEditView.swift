// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Mode du formulaire serveur : création ou édition d'un serveur existant.
enum ServerFormMode: Identifiable {
    case add
    case edit(ServerConfiguration)

    var id: String {
        switch self {
        case .add: "add"
        case let .edit(server): server.id.uuidString
        }
    }
}

/// Formulaire d'ajout/édition d'un serveur : URL, libellé, méthode d'auth, secrets (Keychain
/// via le view-model) et Cloudflare Access. Avertit si le transport est en clair (HTTP).
struct ServerEditView: View {
    let model: ServerListModel
    let mode: ServerFormMode
    @Environment(\.dismiss) private var dismiss

    @State private var urlText: String
    @State private var label: String
    @State private var authMethod: AuthMethod
    @State private var apiKey: String
    @State private var usesCloudflare: Bool
    @State private var cloudflareID: String
    @State private var cloudflareSecret: String
    @State private var saveError: String?
    @State private var loginToken: String?
    @State private var loginUsername: String?
    @State private var showingLogin = false
    @State private var loginModel: LoginModel?

    init(model: ServerListModel, mode: ServerFormMode) {
        self.model = model
        self.mode = mode
        switch mode {
        case .add:
            _urlText = State(initialValue: "")
            _label = State(initialValue: "")
            _authMethod = State(initialValue: .none)
            _apiKey = State(initialValue: "")
            _usesCloudflare = State(initialValue: false)
            _cloudflareID = State(initialValue: "")
            _cloudflareSecret = State(initialValue: "")
            _loginToken = State(initialValue: nil)
        case let .edit(server):
            let secrets = model.secrets(for: server)
            _urlText = State(initialValue: server.baseURL.absoluteString)
            _label = State(initialValue: server.label)
            _authMethod = State(initialValue: server.authMethod)
            _apiKey = State(initialValue: secrets.apiKey ?? "")
            _usesCloudflare = State(initialValue: server.usesCloudflareAccess)
            _cloudflareID = State(initialValue: secrets.cloudflareClientID ?? "")
            _cloudflareSecret = State(initialValue: secrets.cloudflareClientSecret ?? "")
            _loginToken = State(initialValue: secrets.bearerToken)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                serverSection
                if isInsecure {
                    insecureWarning
                }
                authSection
                cloudflareSection
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle(navigationTitleKey)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .alert(
                "Could not save server",
                isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
            ) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "")
            }
            .sheet(isPresented: $showingLogin) {
                if let loginModel {
                    LoginView(model: loginModel) { token, user in
                        loginToken = token
                        loginUsername = user?.username
                    }
                }
            }
        }
    }

    private var serverSection: some View {
        Section("Server") {
            TextField("Server URL", text: $urlText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .textContentType(.URL)
            TextField("Label", text: $label)
        }
    }

    private var insecureWarning: some View {
        Section {
            Label {
                Text("This server uses plain HTTP. Traffic is not encrypted; use only on a trusted network.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DSColor.statusWarning)
            }
            .font(.footnote)
        }
    }

    private var authSection: some View {
        Section("Authentication") {
            Picker("Method", selection: $authMethod) {
                Text("None").tag(AuthMethod.none)
                Text("API key").tag(AuthMethod.apiKey)
                Text("Username & password").tag(AuthMethod.userPassword)
            }
            if authMethod == .apiKey {
                SecureField("API key", text: $apiKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else if authMethod == .userPassword {
                loginRow
            }
        }
    }

    @ViewBuilder
    private var loginRow: some View {
        if loginToken != nil {
            Label {
                if let loginUsername {
                    Text("Signed in as \(loginUsername)")
                } else {
                    Text("Signed in")
                }
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(DSColor.statusOK)
            }
        }
        Button(loginButtonTitle) { startLogin() }
            .disabled(parsedURL == nil)
    }

    private var loginButtonTitle: LocalizedStringKey {
        loginToken == nil ? "Log in" : "Log in again"
    }

    private var draftSecrets: ServerSecrets {
        ServerSecrets(
            cloudflareClientID: usesCloudflare ? cloudflareID.trimmedNonEmpty : nil,
            cloudflareClientSecret: usesCloudflare ? cloudflareSecret.trimmedNonEmpty : nil
        )
    }

    private func startLogin() {
        guard let url = parsedURL else { return }
        loginModel = model.makeLoginModel(baseURL: url, secrets: draftSecrets, usesCloudflare: usesCloudflare)
        showingLogin = true
    }

    private var cloudflareSection: some View {
        Section("Cloudflare Access") {
            Toggle("Use Cloudflare Access", isOn: $usesCloudflare)
            if usesCloudflare {
                TextField("Client ID", text: $cloudflareID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Client Secret", text: $cloudflareSecret)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { true } else { false }
    }

    private var navigationTitleKey: LocalizedStringKey {
        isEditing ? "Edit server" : "New server"
    }

    private var parsedURL: URL? {
        try? ServerURLParser.normalize(urlText)
    }

    private var isInsecure: Bool {
        parsedURL?.scheme?.lowercased() == "http"
    }

    private var canSave: Bool {
        parsedURL != nil && !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        do {
            let url = try ServerURLParser.normalize(urlText)
            let id = if case let .edit(server) = mode {
                server.id
            } else {
                UUID()
            }
            let configuration = ServerConfiguration(
                id: id,
                label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                baseURL: url,
                authMethod: authMethod,
                usesCloudflareAccess: usesCloudflare,
                allowsInsecureLocalHTTP: url.scheme?.lowercased() == "http"
            )
            let secrets = ServerSecrets(
                apiKey: authMethod == .apiKey ? apiKey.trimmedNonEmpty : nil,
                bearerToken: authMethod == .userPassword ? loginToken : nil,
                cloudflareClientID: usesCloudflare ? cloudflareID.trimmedNonEmpty : nil,
                cloudflareClientSecret: usesCloudflare ? cloudflareSecret.trimmedNonEmpty : nil
            )
            try model.save(configuration, secrets: secrets)
            dismiss()
        } catch let error as ServerURLError {
            saveError = Self.message(for: error)
        } catch {
            saveError = error.localizedDescription
        }
    }

    private static func message(for error: ServerURLError) -> String {
        switch error {
        case .empty:
            String(localized: "Enter a server URL.")
        case .invalid:
            String(localized: "This URL is not valid.")
        case let .unsupportedScheme(scheme):
            String(localized: "Unsupported scheme “\(scheme)”. Use http or https.")
        }
    }
}

private extension String {
    /// Valeur sans espaces de bord, ou `nil` si vide — pour ne pas stocker de secret vide.
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    ServerEditView(model: ServerListModel(environment: .inMemory()), mode: .add)
}
