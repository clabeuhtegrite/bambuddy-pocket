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

/// Groupe d'appartenance d'un utilisateur (sous-ensemble).
public struct UserGroup: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var name: String

    public init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}

/// Utilisateur authentifié (`GET /auth/me`, sous-ensemble de `UserResponse`).
public struct User: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var username: String
    public var email: String?
    public var role: String?
    public var isAdmin: Bool?
    public var isActive: Bool?
    public var authSource: String?
    public var groups: [UserGroup]?
    public var createdAt: String?

    public init(
        id: Int,
        username: String,
        email: String? = nil,
        role: String? = nil,
        isAdmin: Bool? = nil,
        isActive: Bool? = nil,
        authSource: String? = nil,
        groups: [UserGroup]? = nil,
        createdAt: String? = nil
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.role = role
        self.isAdmin = isAdmin
        self.isActive = isActive
        self.authSource = authSource
        self.groups = groups
        self.createdAt = createdAt
    }
}

/// État de l'authentification à deux facteurs (`GET /auth/2fa/status`).
public struct TwoFactorStatus: Codable, Sendable, Hashable {
    public var totpEnabled: Bool?
    public var emailOtpEnabled: Bool?
    public var backupCodesRemaining: Int?

    public init(
        totpEnabled: Bool? = nil,
        emailOtpEnabled: Bool? = nil,
        backupCodesRemaining: Int? = nil
    ) {
        self.totpEnabled = totpEnabled
        self.emailOtpEnabled = emailOtpEnabled
        self.backupCodesRemaining = backupCodesRemaining
    }

    /// Au moins une méthode 2FA est-elle active ?
    public var isEnabled: Bool {
        (totpEnabled ?? false) || (emailOtpEnabled ?? false)
    }
}

/// Réponse de `POST /auth/login`. Si `requires2fa`, `accessToken` est absent et il faut vérifier
/// le second facteur via `pre_auth_token`. Sinon `accessToken` est le **JWT** à utiliser en Bearer.
public struct LoginResponse: Decodable, Sendable, Hashable {
    public var accessToken: String?
    public var tokenType: String?
    /// Un second facteur est-il requis ? La clé serveur `requires_2fa` se convertit en
    /// `requires2Fa` (mot commençant par un chiffre) ; le décodage accepte les deux orthographes.
    public var requires2fa: Bool?
    public var preAuthToken: String?
    public var twoFaMethods: [String]?
    public var user: User?

    public init() {}

    /// Un second facteur est-il requis ?
    public var needsTwoFactor: Bool {
        requires2fa ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case accessToken
        case tokenType
        case preAuthToken
        case twoFaMethods
        case user
        case requires2faLower = "requires2fa"
        case requires2faUpper = "requires2Fa"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accessToken = try container.decodeIfPresent(String.self, forKey: .accessToken)
        tokenType = try container.decodeIfPresent(String.self, forKey: .tokenType)
        preAuthToken = try container.decodeIfPresent(String.self, forKey: .preAuthToken)
        twoFaMethods = try container.decodeIfPresent([String].self, forKey: .twoFaMethods)
        user = try container.decodeIfPresent(User.self, forKey: .user)
        let lower = try container.decodeIfPresent(Bool.self, forKey: .requires2faLower)
        let upper = try container.decodeIfPresent(Bool.self, forKey: .requires2faUpper)
        requires2fa = lower ?? upper
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
