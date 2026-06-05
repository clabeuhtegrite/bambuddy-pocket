// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model du compte **Bambu Cloud** d'un serveur (`/cloud/`). Affiche l'état d'authentification
/// (le jeton vit **côté serveur**, jamais sur l'appareil) et orchestre un flux de connexion
/// e-mail/mot de passe + vérification par code.
///
/// Sécurité : le serveur de production est **déjà** authentifié Bambu Cloud — l'app n'a alors qu'à
/// afficher « déjà connecté ». Le flux de connexion ne sert qu'aux serveurs non connectés.
@MainActor
@Observable
final class CloudAccountModel {
    private(set) var status: CloudAuthStatus?
    private(set) var hasLoaded = false
    /// Fonction d'administration réservée à une connexion par identifiants (HTTP 403). Sous une clé
    /// d'API, c'est le comportement **attendu** : l'UI affiche « connexion admin requise » (cf. #70).
    private(set) var isForbidden = false
    /// L'intégration Bambu Cloud n'est pas disponible sur ce serveur (HTTP 404).
    private(set) var isUnavailable = false
    var loadError: String?

    /// État du flux de connexion en cours (saisie identifiants → éventuelle vérification par code).
    private(set) var pendingVerification = false
    private(set) var verificationMessage: String?
    private(set) var isSubmitting = false
    var actionMessage: String?

    /// Conservés en mémoire le temps du flux de vérification (jamais persistés).
    private var pendingEmail: String?
    private var pendingRegion = "global"
    private var pendingTfaKey: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory

    init(server: ServerConfiguration, connectionFactory: ServerConnectionFactory) {
        self.server = server
        self.connectionFactory = connectionFactory
    }

    /// Le compte Bambu Cloud est-il connecté côté serveur ?
    var isAuthenticated: Bool {
        status?.isAuthenticated ?? false
    }

    func load() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            status = try await client.cloudStatus()
            loadError = nil
            isForbidden = false
            isUnavailable = false
        } catch let apiError as APIError where apiError.isForbidden {
            isForbidden = true
            isUnavailable = false
            loadError = ErrorMessage.text(for: apiError)
        } catch let apiError as APIError where apiError.isNotFound {
            isUnavailable = true
            isForbidden = false
            loadError = nil
        } catch {
            isForbidden = false
            isUnavailable = false
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Lance une connexion. Si le compte exige une vérification, bascule en attente de code.
    func login(email: String, password: String, region: String) async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            let response = try await client.loginCloud(
                CloudLoginRequest(email: email, password: password, region: region)
            )
            if response.needsVerification {
                pendingVerification = true
                pendingEmail = email
                pendingRegion = region
                pendingTfaKey = response.tfaKey
                verificationMessage = response.message
            } else if response.success {
                pendingVerification = false
                actionMessage = nil
                await load()
            } else {
                actionMessage = response.message
            }
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }

    /// Soumet le code de vérification reçu par e-mail pour finaliser la connexion.
    func verify(code: String) async {
        guard let email = pendingEmail else { return }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let client = try connectionFactory.makeClient(for: server)
            let response = try await client.verifyCloud(
                CloudVerifyRequest(email: email, code: code, tfaKey: pendingTfaKey, region: pendingRegion)
            )
            if response.success {
                resetFlow()
                actionMessage = nil
                await load()
            } else {
                actionMessage = response.message
            }
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }

    /// Déconnecte le compte Bambu Cloud côté serveur puis recharge l'état.
    func logout() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.logoutCloud()
            resetFlow()
            await load()
        } catch {
            actionMessage = ErrorMessage.text(for: error)
        }
    }

    /// Annule un flux de vérification en cours (retour à la saisie des identifiants).
    func cancelVerification() {
        resetFlow()
    }

    private func resetFlow() {
        pendingVerification = false
        pendingEmail = nil
        pendingTfaKey = nil
        pendingRegion = "global"
        verificationMessage = nil
    }
}
