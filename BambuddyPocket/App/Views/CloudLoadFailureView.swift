// SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

/// État d'**échec de chargement** partagé par les écrans cloud/sauvegarde (Bambu Cloud, MakerWorld,
/// sauvegardes, sauvegarde distante GitHub, clés d'API). Ces écrans rendaient tous le même triptyque
/// `ContentUnavailableView` — accès admin requis (403), fonction indisponible sur ce serveur, ou
/// échec de chargement générique — au libellé de fonction près. Factorisé ici (B2).
///
/// L'appelant passe les drapeaux de son modèle ; l'ordre de priorité reproduit l'ancien
/// comportement : `isForbidden` > `isUnavailable` > `loadError`. Rend une vue vide si aucun ne
/// s'applique (l'appelant n'affiche le placeholder que dans un overlay déjà conditionné).
struct CloudLoadFailureView: View {
    /// Titre spécifique à la fonction pour l'échec générique (« Couldn't load … »).
    let loadFailureTitle: LocalizedStringKey
    let isForbidden: Bool
    /// `false` pour les écrans sans état « indisponible » (ex. clés d'API).
    var isUnavailable: Bool = false
    /// Message d'erreur détaillé (déjà localisé) ; `nil` si l'échec n'est pas un échec de chargement.
    let loadError: String?

    var body: some View {
        if isForbidden {
            ContentUnavailableView {
                Label("Admin login required", systemImage: "lock")
            } description: {
                Text("Admin login required — reconfigure this server with a username & password.")
            }
        } else if isUnavailable {
            ContentUnavailableView {
                Label("Not available", systemImage: "questionmark.circle")
            } description: {
                Text("Not available on this server.")
            }
        } else if let loadError {
            ContentUnavailableView {
                Label(loadFailureTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(loadError)
            }
        }
    }
}
