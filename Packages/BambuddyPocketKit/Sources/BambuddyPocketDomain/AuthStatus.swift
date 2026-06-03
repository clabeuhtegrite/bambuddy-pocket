// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État d'authentification d'une instance (`GET /api/v1/auth/status`).
public struct AuthStatus: Codable, Sendable, Hashable {
    /// L'auth est-elle activée sur le serveur ?
    public var authEnabled: Bool
    /// Le serveur attend-il une configuration initiale (setup) ?
    public var requiresSetup: Bool?

    public init(authEnabled: Bool, requiresSetup: Bool? = nil) {
        self.authEnabled = authEnabled
        self.requiresSetup = requiresSetup
    }
}
