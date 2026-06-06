// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Compte **Bambu Cloud** d'un serveur : affiche l'état d'authentification (le jeton vit côté
/// serveur). Lorsque le serveur n'est pas connecté, propose un flux de connexion e-mail/mot de passe
/// avec vérification par code. Gardé admin → message « connexion admin requise » sous clé d'API.
struct CloudAccountView: View {
    @State private var model: CloudAccountModel

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeCloudAccountModel(for: server))
    }

    /// Échec de chargement sans données : on n'affiche que l'état d'erreur (admin/indispo/erreur).
    private var showsLoadFailure: Bool {
        model.status == nil && (model.isForbidden || model.isUnavailable || model.loadError != nil)
    }

    var body: some View {
        List {
            if !showsLoadFailure {
                statusSection
                if model.hasLoaded {
                    if model.isAuthenticated {
                        connectedActionsSection
                    } else {
                        loginSection
                    }
                }
                if let message = model.actionMessage {
                    Section { Text(message).font(DSFont.caption).foregroundStyle(DSColor.textSecondary) }
                }
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Bambu Cloud")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
    }

    private var statusSection: some View {
        Section("Status") {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: model.isAuthenticated ? "checkmark.icloud" : "icloud.slash")
                    .foregroundStyle(model.isAuthenticated ? DSColor.statusOK : DSColor.textSecondary)
                    .accessibilityHidden(true)
                Text(model.isAuthenticated ? "Connected" : "Not connected")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
            if let status = model.status {
                if let email = status.email, !email.isEmpty {
                    LabeledContent("Account", value: email)
                }
                if let region = status.region, !region.isEmpty {
                    LabeledContent("Region", value: region.capitalized)
                }
            }
        }
    }

    private var connectedActionsSection: some View {
        Section {
            Button("Sign out", role: .destructive) {
                Task { await model.logout() }
            }
        } footer: {
            Text("The Bambu Cloud session is stored on the server. Signing out clears it server-side.")
                .font(DSFont.caption)
        }
    }

    @ViewBuilder
    private var loginSection: some View {
        if model.pendingVerification {
            CloudVerificationForm(model: model)
        } else {
            CloudLoginForm(model: model)
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if !model.hasLoaded {
            ProgressView().tint(DSColor.accent)
        } else {
            CloudLoadFailureView(
                loadFailureTitle: "Couldn’t load Bambu Cloud",
                isForbidden: model.isForbidden,
                isUnavailable: model.isUnavailable,
                loadError: showsLoadFailure ? model.loadError : nil
            )
        }
    }
}

/// Saisie des identifiants Bambu Cloud (e-mail / mot de passe / région).
private struct CloudLoginForm: View {
    @Bindable var model: CloudAccountModel
    @State private var email = ""
    @State private var password = ""
    @State private var region = "global"

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !model.isSubmitting
    }

    var body: some View {
        Section {
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            SecureField("Password", text: $password)
                .textContentType(.password)
            Picker("Region", selection: $region) {
                Text("Global").tag("global")
                Text("China").tag("china")
            }
            Button {
                Task { await model.login(email: email, password: password, region: region) }
            } label: {
                HStack {
                    Text("Sign in")
                    Spacer()
                    if model.isSubmitting { ProgressView() }
                }
            }
            .disabled(!canSubmit)
        } header: {
            Text("Sign in")
        } footer: {
            Text(
                "Credentials are sent to the server to obtain a Bambu Cloud token. Never stored on this device."
            )
            .font(DSFont.caption)
        }
    }
}

/// Saisie du code de vérification reçu par e-mail.
private struct CloudVerificationForm: View {
    @Bindable var model: CloudAccountModel
    @State private var code = ""

    var body: some View {
        Section("Verification") {
            if let message = model.verificationMessage, !message.isEmpty {
                Text(message).font(DSFont.caption).foregroundStyle(DSColor.textSecondary)
            }
            TextField("Verification code", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
            Button {
                Task { await model.verify(code: code) }
            } label: {
                HStack {
                    Text("Verify")
                    Spacer()
                    if model.isSubmitting { ProgressView() }
                }
            }
            .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || model.isSubmitting)
            Button("Cancel", role: .cancel) {
                model.cancelVerification()
            }
        }
    }
}

#Preview {
    NavigationStack {
        CloudAccountView(
            server: ServerConfiguration(
                label: "Atelier",
                baseURL: URL(string: "http://192.168.1.50:8000") ?? URL(filePath: "/")
            ),
            serverList: ServerListModel(environment: .inMemory())
        )
    }
}
