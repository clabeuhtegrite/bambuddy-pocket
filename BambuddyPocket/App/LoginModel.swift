// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// Pilote le flux de connexion par identifiants : saisie, puis second facteur si nécessaire.
/// Au succès, `token` porte le JWT à stocker en Bearer.
@MainActor
@Observable
final class LoginModel: Identifiable {
    enum Step: Equatable {
        case credentials
        case twoFactor
    }

    /// Méthode de second facteur retenue pour cette session de connexion. Détermine le **libellé**
    /// du prompt (code reçu par email vs code de l'app d'authentification) et le `method` envoyé à
    /// `POST /auth/2fa/verify`.
    enum TwoFactorMethod: Equatable {
        case totp
        case email
    }

    /// Identité stable pour piloter la présentation par `sheet(item:)` (évite la double
    /// présentation / la sheet vide quand `isPresented` et le modèle sont posés au même tour de
    /// boucle — retour device A3).
    let id = UUID()

    private(set) var step: Step = .credentials
    var username = ""
    var password = ""
    var code = ""
    private(set) var methods: [String] = []
    /// Méthode 2FA effective (renseignée à l'entrée de l'étape `twoFactor`).
    private(set) var twoFactorMethod: TwoFactorMethod = .totp
    private(set) var isWorking = false
    /// Un renvoi de code email est-il en cours ? (bouton « Renvoyer » désactivé pendant l'envoi)
    private(set) var isResending = false
    var error: String?
    private(set) var token: String?
    private(set) var user: User?

    private var preAuthToken: String?
    private let client: RESTClient

    init(client: RESTClient) {
        self.client = client
    }

    var canSubmit: Bool {
        switch step {
        case .credentials: !username.isEmpty && !password.isEmpty
        case .twoFactor: !code.isEmpty
        }
    }

    /// Le second facteur courant est-il une OTP envoyée par email (vs un code TOTP) ? Pilote
    /// l'affichage du bouton « Renvoyer le code » et le libellé du champ.
    var isEmailOTP: Bool {
        twoFactorMethod == .email
    }

    func submit() async {
        isWorking = true
        error = nil
        do {
            switch step {
            case .credentials:
                try await submitCredentials()
            case .twoFactor:
                try await submitTwoFactor()
            }
        } catch {
            self.error = ErrorMessage.text(for: error)
        }
        isWorking = false
    }

    private func submitCredentials() async throws {
        let response = try await client.login(username: username, password: password)
        if response.needsTwoFactor {
            preAuthToken = response.preAuthToken
            methods = response.twoFaMethods ?? []
            // TOTP prime sur email (l'app d'authentification est instantanée) ; sinon, si seule la
            // 2FA email est active, on déclenche l'envoi du mail. `backup` reste un repli silencieux.
            if methods.contains("totp") {
                twoFactorMethod = .totp
            } else if methods.contains("email") {
                twoFactorMethod = .email
            } else {
                twoFactorMethod = .totp
            }
            step = .twoFactor
            // 2FA email : déclencher l'envoi du code **maintenant** (sinon aucun mail n'est envoyé et
            // l'utilisateur n'a aucun code à saisir — retour device A4).
            if twoFactorMethod == .email {
                try await sendEmailCode()
            }
        } else if let accessToken = response.accessToken {
            token = accessToken
            user = response.user
        } else {
            error = String(localized: "Login failed.")
        }
    }

    /// Demande au serveur d'envoyer (ou ré-envoyer) l'OTP par email. Le serveur consomme l'ancien
    /// `pre_auth_token` et en renvoie un frais qu'on adopte pour la vérification.
    private func sendEmailCode() async throws {
        guard let token = preAuthToken else { return }
        let response = try await client.sendEmailOTP(preAuthToken: token)
        if let fresh = response.preAuthToken {
            preAuthToken = fresh
        }
    }

    /// Renvoie le code email à la demande de l'utilisateur (bouton « Renvoyer le code »).
    func resendEmailCode() async {
        guard twoFactorMethod == .email, !isResending else { return }
        isResending = true
        error = nil
        do {
            try await sendEmailCode()
        } catch {
            self.error = ErrorMessage.text(for: error)
        }
        isResending = false
    }

    private func submitTwoFactor() async throws {
        guard let preAuthToken else { return }
        let response = try await client.verifyTwoFactor(
            preAuthToken: preAuthToken,
            code: code,
            method: verifyMethod
        )
        token = response.accessToken
        user = response.user
    }

    /// Valeur `method` envoyée à `POST /auth/2fa/verify` (`"totp"` / `"email"`).
    private var verifyMethod: String {
        switch twoFactorMethod {
        case .totp: "totp"
        case .email: "email"
        }
    }
}
