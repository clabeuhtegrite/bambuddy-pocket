// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// Pilote le flux de connexion par identifiants : saisie, puis second facteur si nécessaire.
/// Au succès, `token` porte le JWT à stocker en Bearer.
@MainActor
@Observable
final class LoginModel {
    enum Step: Equatable {
        case credentials
        case twoFactor
    }

    private(set) var step: Step = .credentials
    var username = ""
    var password = ""
    var code = ""
    private(set) var methods: [String] = []
    private(set) var isWorking = false
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
            step = .twoFactor
        } else if let accessToken = response.accessToken {
            token = accessToken
            user = response.user
        } else {
            error = String(localized: "Login failed.")
        }
    }

    private func submitTwoFactor() async throws {
        guard let preAuthToken else { return }
        let response = try await client.verifyTwoFactor(
            preAuthToken: preAuthToken,
            code: code,
            method: methods.first
        )
        token = response.accessToken
        user = response.user
    }
}
