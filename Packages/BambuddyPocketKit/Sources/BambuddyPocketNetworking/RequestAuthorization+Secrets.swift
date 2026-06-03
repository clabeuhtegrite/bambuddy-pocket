// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketDomain

public extension RequestAuthorization {
    /// Construit l'autorisation à partir des secrets stockés et de la config du serveur :
    /// Bearer/X-API-Key selon la méthode d'auth, en-têtes Cloudflare si activés.
    init(secrets: ServerSecrets, authMethod: AuthMethod, usesCloudflareAccess: Bool) {
        var bearer: String?
        var key: String?
        switch authMethod {
        case .none:
            break
        case .apiKey:
            key = secrets.apiKey
        case .userPassword:
            bearer = secrets.bearerToken
        }
        self.init(
            bearerToken: bearer,
            apiKey: key,
            cloudflareClientID: usesCloudflareAccess ? secrets.cloudflareClientID : nil,
            cloudflareClientSecret: usesCloudflareAccess ? secrets.cloudflareClientSecret : nil
        )
    }

    /// Variante directe à partir d'une `ServerConfiguration` + ses secrets.
    init(configuration: ServerConfiguration, secrets: ServerSecrets) {
        self.init(
            secrets: secrets,
            authMethod: configuration.authMethod,
            usesCloudflareAccess: configuration.usesCloudflareAccess
        )
    }
}
