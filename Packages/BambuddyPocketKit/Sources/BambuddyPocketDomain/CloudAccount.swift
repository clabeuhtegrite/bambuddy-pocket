// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// État d'authentification au compte Bambu Cloud côté serveur (`GET /cloud/status`).
/// Le serveur stocke le jeton ; l'app se contente d'afficher l'état (lecture seule).
public struct CloudAuthStatus: Codable, Sendable, Hashable {
    public var isAuthenticated: Bool
    public var email: String?
    public var region: String?

    public init(isAuthenticated: Bool = false, email: String? = nil, region: String? = nil) {
        self.isAuthenticated = isAuthenticated
        self.email = email
        self.region = region
    }
}

/// Corps de connexion au compte Bambu Cloud (`POST /cloud/login`).
/// La région par défaut est mondiale (`global`) ; `china` pour les comptes Bambu chinois.
public struct CloudLoginRequest: Codable, Sendable, Hashable {
    public var email: String
    public var password: String
    public var region: String

    public init(email: String, password: String, region: String = "global") {
        self.email = email
        self.password = password
        self.region = region
    }
}

/// Réponse de `POST /cloud/login` ou `POST /cloud/verify`.
/// Lorsque `needsVerification` est vrai, l'app doit demander un code (e-mail) puis appeler
/// `/cloud/verify` en transmettant `tfaKey` s'il est fourni.
public struct CloudLoginResponse: Codable, Sendable, Hashable {
    public var success: Bool
    public var needsVerification: Bool
    public var message: String
    public var verificationType: String?
    public var tfaKey: String?

    public init(
        success: Bool,
        needsVerification: Bool = false,
        message: String,
        verificationType: String? = nil,
        tfaKey: String? = nil
    ) {
        self.success = success
        self.needsVerification = needsVerification
        self.message = message
        self.verificationType = verificationType
        self.tfaKey = tfaKey
    }
}

/// Corps de vérification du code reçu par e-mail (`POST /cloud/verify`).
public struct CloudVerifyRequest: Codable, Sendable, Hashable {
    public var email: String
    public var code: String
    public var tfaKey: String?
    public var region: String

    public init(email: String, code: String, tfaKey: String? = nil, region: String = "global") {
        self.email = email
        self.code = code
        self.tfaKey = tfaKey
        self.region = region
    }
}
