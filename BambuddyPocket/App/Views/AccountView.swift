// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDesignSystem
import BambuddyPocketDomain
import SwiftUI

/// Compte/profil de l'utilisateur connecté : identité, rôle, groupes, état 2FA et déconnexion.
/// N'est pertinent que pour un serveur authentifié par identifiants (`userPassword`).
struct AccountView: View {
    @State private var model: AccountModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingLogout = false

    init(server: ServerConfiguration, serverList: ServerListModel) {
        _model = State(initialValue: serverList.makeAccountModel(for: server))
    }

    var body: some View {
        List {
            if !model.requiresAuthentication {
                noAuthSection
            } else if let user = model.user {
                profileSection(user)
                if let twoFactor = model.twoFactor {
                    twoFactorSection(twoFactor)
                }
                logoutSection
            }
        }
        .dsListBackground()
        .overlay { placeholder }
        .navigationTitle("Account")
        .toolbarTitleDisplayMode(.inline)
        .refreshable { await model.load() }
        .task {
            if !model.hasLoaded {
                await model.load()
            }
        }
        .confirmationDialog("Log out?", isPresented: $confirmingLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) {
                Task {
                    await model.logout()
                    if model.didLogout {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Your session token will be revoked and removed from this device.")
        }
    }

    private var noAuthSection: some View {
        Section {
            ContentUnavailableView(
                "No account",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("This server does not require authentication.")
            )
        }
    }

    private func profileSection(_ user: User) -> some View {
        Section("Profile") {
            LabeledContent("Username", value: user.username)
            if let email = user.email {
                LabeledContent("Email", value: email)
            }
            if let role = user.role {
                LabeledContent("Role", value: role)
            }
            if let source = user.authSource {
                LabeledContent("Authentication", value: source)
            }
            if let groups = user.groups, !groups.isEmpty {
                LabeledContent("Groups", value: groups.map(\.name).joined(separator: ", "))
            }
        }
    }

    private func twoFactorSection(_ twoFactor: TwoFactorStatus) -> some View {
        Section("Two-factor authentication") {
            HStack(spacing: DSSpacing.sm) {
                Image(systemName: twoFactor.isEnabled ? "lock.shield.fill" : "lock.open")
                    .foregroundStyle(twoFactor.isEnabled ? DSColor.statusOK : DSColor.statusWarning)
                Text(twoFactor.isEnabled ? "Enabled" : "Disabled")
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPrimary)
            }
            if twoFactor.totpEnabled == true {
                LabeledContent("Authenticator app", value: String(localized: "On"))
            }
            if twoFactor.emailOtpEnabled == true {
                LabeledContent("Email codes", value: String(localized: "On"))
            }
            if let remaining = twoFactor.backupCodesRemaining, twoFactor.isEnabled {
                LabeledContent("Backup codes", value: "\(remaining)")
            }
        }
    }

    private var logoutSection: some View {
        Section {
            Button("Log out", role: .destructive) {
                confirmingLogout = true
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if model.requiresAuthentication, !model.hasLoaded, model.user == nil {
            ProgressView().tint(DSColor.accent)
        } else if model.requiresAuthentication, model.user == nil, let error = model.loadError {
            ContentUnavailableView {
                Label("Couldn’t load account", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            }
        }
    }
}
