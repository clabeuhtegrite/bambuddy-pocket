// SPDX-License-Identifier: AGPL-3.0-or-later
import BambuddyPocketNetworking
import Foundation

/// Traduction d'une erreur réseau en message présentable à l'utilisateur (localisé).
enum ErrorMessage {
    static func text(for error: Error) -> String {
        switch error {
        case let apiError as APIError:
            text(for: apiError)
        default:
            error.localizedDescription
        }
    }

    static func text(for error: APIError) -> String {
        switch error {
        case .invalidURL:
            String(localized: "The server URL is not valid.")
        case .unauthorized:
            String(localized: "Unauthorized — check your credentials.")
        case let .transport(message):
            message
        case let .http(status, _):
            String(localized: "The server returned an unexpected status (\(status)).")
        case .decoding:
            String(localized: "The server response could not be read.")
        case let .server(message):
            message
        }
    }
}
