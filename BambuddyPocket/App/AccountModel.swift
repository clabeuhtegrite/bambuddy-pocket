// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain
import BambuddyPocketNetworking
import Foundation
import Observation

/// View-model du compte/profil de l'utilisateur connecté à un serveur authentifié :
/// profil (`GET /auth/me`), état 2FA (`GET /auth/2fa/status`) et déconnexion (`POST /auth/logout`).
@MainActor
@Observable
final class AccountModel {
    private(set) var user: User?
    private(set) var twoFactor: TwoFactorStatus?
    private(set) var hasLoaded = false
    private(set) var didLogout = false
    var loadError: String?

    private let server: ServerConfiguration
    private let connectionFactory: ServerConnectionFactory
    private weak var serverList: ServerListModel?

    init(
        server: ServerConfiguration,
        connectionFactory: ServerConnectionFactory,
        serverList: ServerListModel
    ) {
        self.server = server
        self.connectionFactory = connectionFactory
        self.serverList = serverList
    }

    /// Le serveur requiert-il une authentification (profil pertinent) ?
    var requiresAuthentication: Bool {
        server.authMethod == .userPassword
    }

    func load() async {
        guard requiresAuthentication else {
            hasLoaded = true
            return
        }
        do {
            let client = try connectionFactory.makeClient(for: server)
            user = try await client.currentUser()
            twoFactor = try? await client.twoFactorStatus()
            loadError = nil
        } catch {
            loadError = ErrorMessage.text(for: error)
        }
        hasLoaded = true
    }

    /// Déconnecte l'utilisateur : révoque le jeton serveur puis efface le JWT local.
    func logout() async {
        do {
            let client = try connectionFactory.makeClient(for: server)
            try await client.logout()
        } catch {
            // La révocation côté serveur peut échouer (token déjà expiré) : on efface quand même
            // le jeton local pour ne pas laisser l'app dans un état authentifié incohérent.
        }
        serverList?.clearBearerToken(for: server)
        user = nil
        twoFactor = nil
        didLogout = true
    }
}
