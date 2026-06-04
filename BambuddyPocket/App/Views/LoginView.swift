// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Écran de connexion par identifiants (avec étape 2FA si le serveur l'exige).
/// Appelle `onSuccess` avec le JWT obtenu, puis se ferme.
struct LoginView: View {
    @Bindable var model: LoginModel
    let onSuccess: (String, User?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                switch model.step {
                case .credentials:
                    Section("Credentials") {
                        TextField("Username", text: $model.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("Password", text: $model.password)
                    }
                case .twoFactor:
                    Section("Two-factor code") {
                        TextField("Code", text: $model.code)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.numberPad)
                    }
                }
                if let error = model.error {
                    Section {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(DSColor.statusError)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DSColor.background)
            .navigationTitle("Log in")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitTitle) {
                        Task { await model.submit() }
                    }
                    .disabled(!model.canSubmit || model.isWorking)
                }
            }
            .onChange(of: model.token) { _, newValue in
                if let newValue {
                    onSuccess(newValue, model.user)
                    dismiss()
                }
            }
        }
    }

    private var submitTitle: LocalizedStringKey {
        model.step == .credentials ? "Continue" : "Verify"
    }
}
