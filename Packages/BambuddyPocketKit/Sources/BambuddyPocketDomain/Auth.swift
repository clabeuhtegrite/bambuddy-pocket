// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Identifiants de connexion (`POST /auth/login`).
public struct LoginRequest: Codable, Sendable, Hashable {
    public var username: String
    public var password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

/// Utilisateur authentifié (sous-ensemble de `UserResponse`).
public struct User: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var username: String
    public var email: String?
    public var role: String?
    public var isAdmin: Bool?

    public init(id: Int, username: String, email: String? = nil, role: String? = nil, isAdmin: Bool? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.role = role
        self.isAdmin = isAdmin
    }
}

/// Réponse de `POST /auth/login`. Si `requires2fa`, `accessToken` est absent et il faut vérifier
/// le second facteur via `pre_auth_token`. Sinon `accessToken` est le **JWT** à utiliser en Bearer.
public struct LoginResponse: Codable, Sendable, Hashable {
    public var accessToken: String?
    public var tokenType: String?
    public var requires2fa: Bool?
    public var preAuthToken: String?
    public var twoFaMethods: [String]?
    public var user: User?

    public init() {}

    /// Un second facteur est-il requis ?
    public var needsTwoFactor: Bool {
        requires2fa ?? false
    }
}

/// Vérification du second facteur (`POST /auth/2fa/verify`).
public struct TwoFAVerifyRequest: Codable, Sendable, Hashable {
    public var preAuthToken: String
    public var code: String
    public var method: String?

    public init(preAuthToken: String, code: String, method: String? = nil) {
        self.preAuthToken = preAuthToken
        self.code = code
        self.method = method
    }
}

/// Réponse de `POST /auth/2fa/verify` : contient le JWT final.
public struct TwoFAVerifyResponse: Codable, Sendable, Hashable {
    public var accessToken: String
    public var tokenType: String?
    public var user: User?

    public init(accessToken: String, tokenType: String? = nil, user: User? = nil) {
        self.accessToken = accessToken
        self.tokenType = tokenType
        self.user = user
    }
}
